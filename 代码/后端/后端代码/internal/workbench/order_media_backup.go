// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
)

type BackupMedia struct {
	ID     string `json:"id"`
	SHA256 string `json:"sha256"`
	Bytes  int64  `json:"bytes"`
}
type mediaReference struct {
	Size   int64
	SHA256 string
}

func snapshotMedia(raw []byte) (map[string]mediaReference, error) {
	var state State
	if err := json.Unmarshal(raw, &state); err != nil {
		return nil, err
	}
	refs := map[string]mediaReference{}
	for _, order := range state.Orders {
		for _, file := range order.Evidence {
			if file.BlobID != "" && !file.Deleted {
				refs[file.BlobID] = mediaReference{file.Size, file.SHA256}
			}
		}
	}
	for _, upload := range state.OrderUploads {
		if !upload.Canceled && upload.OrderID == "" {
			refs[upload.ID] = mediaReference{upload.Size, upload.SHA256}
		}
	}
	return refs, nil
}
func copyEncryptedMedia(source, destination string) (string, int64, error) {
	input, err := os.Open(source)
	if err != nil {
		return "", 0, err
	}
	defer input.Close()
	if err = os.MkdirAll(filepath.Dir(destination), 0700); err != nil {
		return "", 0, err
	}
	output, err := os.OpenFile(destination, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return "", 0, err
	}
	digest := sha256.New()
	size, err := io.CopyBuffer(io.MultiWriter(output, digest), input, make([]byte, orderMediaChunk))
	if err == nil {
		err = output.Sync()
	}
	closeErr := output.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		os.Remove(destination)
		return "", 0, err
	}
	return hex.EncodeToString(digest.Sum(nil)), size, nil
}
func verifyMedia(store *orderMediaStore, id string, ref mediaReference) error {
	reader, err := store.open(context.Background(), id, ref.Size, ref.SHA256)
	if err != nil {
		return err
	}
	defer reader.Close()
	_, err = io.CopyBuffer(io.Discard, reader, make([]byte, orderMediaChunk))
	return err
}
func backupOrderMedia(p Persistence, raw []byte, destination string) ([]BackupMedia, error) {
	refs, err := snapshotMedia(raw)
	if err != nil || len(refs) == 0 {
		return nil, err
	}
	store, err := newOrderMediaStore(p)
	if err != nil {
		return nil, err
	}
	if store == nil {
		return nil, errors.New("备份缺少私有原件来源")
	}
	target := destination + ".media"
	if _, err = os.Stat(target); !errors.Is(err, os.ErrNotExist) {
		return nil, errors.New("原件备份目标已存在或不可访问")
	}
	if err = os.MkdirAll(filepath.Dir(target), 0700); err != nil {
		return nil, err
	}
	staging, err := os.MkdirTemp(filepath.Dir(target), ".media-backup-*")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(staging)
	media := []BackupMedia{}
	for id, ref := range refs {
		if err = verifyMedia(store, id, ref); err != nil {
			return nil, err
		}
		path, err := store.path(id)
		if err != nil {
			return nil, err
		}
		sum, size, err := copyEncryptedMedia(path, filepath.Join(staging, id+".enc"))
		if err != nil {
			return nil, err
		}
		media = append(media, BackupMedia{ID: id, SHA256: sum, Bytes: size})
	}
	if err = os.Rename(staging, target); err != nil {
		return nil, err
	}
	return media, nil
}
func restoreOrderMedia(raw []byte, manifest BackupManifest, backupFile, target string, key []byte) error {
	refs, err := snapshotMedia(raw)
	if err != nil {
		return err
	}
	listed := map[string]BackupMedia{}
	for _, entry := range manifest.Media {
		if _, exists := listed[entry.ID]; exists {
			return errors.New("备份原件清单重复")
		}
		listed[entry.ID] = entry
	}
	source := &orderMediaStore{dir: backupFile + ".media", key: key}
	for id, ref := range refs {
		entry, ok := listed[id]
		if !ok {
			return errors.New("备份原件清单缺失，拒绝恢复")
		}
		path, err := source.path(id)
		if err != nil {
			return err
		}
		sum, size, err := copyEncryptedMedia(path, filepath.Join(target, "order-media", id+".enc"))
		if err != nil {
			return err
		}
		if sum != entry.SHA256 || size != entry.Bytes {
			return errors.New("备份原件摘要校验失败")
		}
		if err = verifyMedia(&orderMediaStore{dir: filepath.Join(target, "order-media"), key: key}, id, ref); err != nil {
			return err
		}
	}
	return nil
}

func verifyBackupOrderMedia(raw []byte, manifest BackupManifest, backupFile string, key []byte) error {
	refs, err := snapshotMedia(raw)
	if err != nil {
		return err
	}
	listed := map[string]BackupMedia{}
	for _, entry := range manifest.Media {
		if _, exists := listed[entry.ID]; exists {
			return errors.New("备份原件清单重复")
		}
		listed[entry.ID] = entry
	}
	store := &orderMediaStore{dir: backupFile + ".media", key: key}
	for id, ref := range refs {
		entry, exists := listed[id]
		if !exists {
			return errors.New("备份原件清单缺失")
		}
		path, err := store.path(id)
		if err != nil {
			return err
		}
		input, err := os.Open(path)
		if err != nil {
			return err
		}
		digest := sha256.New()
		size, err := io.CopyBuffer(digest, input, make([]byte, orderMediaChunk))
		input.Close()
		if err != nil {
			return err
		}
		if size != entry.Bytes || hex.EncodeToString(digest.Sum(nil)) != entry.SHA256 {
			return errors.New("备份原件摘要校验失败")
		}
		if err = verifyMedia(store, id, ref); err != nil {
			return err
		}
	}
	return nil
}
