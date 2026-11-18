// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"hash"
	"io"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const orderMediaChunk = 64 * 1024
const orderMediaFormat = "WBOM1\n"

type OrderUpload struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	MIME        string `json:"mime"`
	Size        int64  `json:"size"`
	SHA256      string `json:"sha256"`
	ActorID     string `json:"actorId"`
	CompanyID   string `json:"companyId"`
	AuthVersion int    `json:"authVersion"`
	RequestKey  string `json:"requestKey"`
	OrderID     string `json:"orderId,omitempty"`
	Canceled    bool   `json:"canceled,omitempty"`
	CreatedAt   string `json:"createdAt"`
}

func (u OrderUpload) receipt() any {
	return struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		MIME   string `json:"mime"`
		Size   int64  `json:"size"`
		SHA256 string `json:"sha256"`
	}{u.ID, u.Name, u.MIME, u.Size, u.SHA256}
}

type orderMediaStore struct {
	dir string
	key []byte
}

func newOrderMediaStore(p Persistence) (*orderMediaStore, error) {
	var dir string
	var key []byte
	switch v := p.(type) {
	case *FilePersistence:
		dir, key = filepath.Join(v.dir, "order-media"), v.key
	case *TiDBPersistence:
		dir, key = v.mediaDir, v.key
	default:
		return nil, nil // Custom persistence can continue using the legacy inline contract.
	}
	if override := os.Getenv("WB_ORDER_MEDIA_DIR"); override != "" {
		dir = override
	}
	if dir == "" {
		return nil, errors.New("设备附件私有目录未配置")
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	return &orderMediaStore{dir: dir, key: key}, nil
}
func (m *orderMediaStore) path(id string) (string, error) {
	if !strings.HasPrefix(id, "upload_") || len(id) != 39 {
		return "", errors.New("原件标识无效")
	}
	if _, err := hex.DecodeString(id[7:]); err != nil {
		return "", err
	}
	return filepath.Join(m.dir, id+".enc"), nil
}
func (m *orderMediaStore) aead() (cipher.AEAD, error) {
	block, err := aes.NewCipher(m.key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}
func mediaAAD(id string, index uint64, size uint32) []byte {
	value := make([]byte, len(orderMediaFormat)+len(id)+12)
	copy(value, orderMediaFormat+id)
	binary.BigEndian.PutUint64(value[len(value)-12:], index)
	binary.BigEndian.PutUint32(value[len(value)-4:], size)
	return value
}

type mediaContextReader struct {
	ctx    context.Context
	reader io.Reader
}

func (r mediaContextReader) Read(p []byte) (int, error) {
	if err := r.ctx.Err(); err != nil {
		return 0, err
	}
	return r.reader.Read(p)
}

// Every frame authenticates its position and length; an authenticated empty frame seals EOF.
func (m *orderMediaStore) put(ctx context.Context, id string, src io.Reader) (int64, string, error) {
	path, err := m.path(id)
	if err != nil {
		return 0, "", err
	}
	aead, err := m.aead()
	if err != nil {
		return 0, "", err
	}
	file, err := os.CreateTemp(m.dir, ".upload-*")
	if err != nil {
		return 0, "", err
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if err = file.Chmod(0600); err != nil {
		return 0, "", err
	}
	if _, err = io.WriteString(file, orderMediaFormat); err != nil {
		return 0, "", err
	}
	data := make([]byte, orderMediaChunk)
	digest := sha256.New()
	var total int64
	for index := uint64(0); ; index++ {
		n, readErr := io.ReadFull(mediaContextReader{ctx, src}, data)
		if readErr != nil && readErr != io.EOF && readErr != io.ErrUnexpectedEOF {
			return 0, "", readErr
		}
		if total > int64(^uint64(0)>>1)-int64(n) {
			return 0, "", errors.New("文件长度超出存储整数范围")
		}
		total += int64(n)
		digest.Write(data[:n])
		nonce := make([]byte, aead.NonceSize())
		if _, err = rand.Read(nonce); err != nil {
			return 0, "", err
		}
		var header [4]byte
		binary.BigEndian.PutUint32(header[:], uint32(n))
		for _, piece := range [][]byte{header[:], nonce, aead.Seal(nil, nonce, data[:n], mediaAAD(id, index, uint32(n)))} {
			if _, err = file.Write(piece); err != nil {
				return 0, "", err
			}
		}
		if n == 0 {
			break
		}
	}
	if err = ctx.Err(); err != nil {
		return 0, "", err
	}
	if err = file.Sync(); err != nil {
		return 0, "", err
	}
	if err = file.Close(); err != nil {
		return 0, "", err
	}
	if err = os.Rename(file.Name(), path); err != nil {
		return 0, "", err
	}
	if directory, e := os.Open(m.dir); e == nil {
		_ = directory.Sync()
		_ = directory.Close()
	}
	return total, hex.EncodeToString(digest.Sum(nil)), nil
}

type orderMediaReader struct {
	file         *os.File
	aead         cipher.AEAD
	ctx          context.Context
	id           string
	index        uint64
	buffer       []byte
	digest       hash.Hash
	size         int64
	expectedSize int64
	expectedHash string
	done         bool
}

func (m *orderMediaStore) open(ctx context.Context, id string, size int64, sum string) (*orderMediaReader, error) {
	path, err := m.path(id)
	if err != nil {
		return nil, err
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	aead, err := m.aead()
	if err != nil {
		file.Close()
		return nil, err
	}
	header := make([]byte, len(orderMediaFormat))
	_, err = io.ReadFull(file, header)
	if err != nil || string(header) != orderMediaFormat {
		file.Close()
		return nil, errors.New("原件加密格式无效")
	}
	return &orderMediaReader{file: file, aead: aead, ctx: ctx, id: id, digest: sha256.New(), expectedSize: size, expectedHash: sum}, nil
}
func (r *orderMediaReader) Close() error { return r.file.Close() }
func (r *orderMediaReader) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	if err := r.ctx.Err(); err != nil {
		return 0, err
	}
	if len(r.buffer) > 0 {
		n := copy(p, r.buffer)
		r.buffer = r.buffer[n:]
		return n, nil
	}
	if r.done {
		return 0, io.EOF
	}
	data, err := r.readFrame()
	if err != nil {
		return 0, err
	}
	if len(data) == 0 {
		if err = r.finish(); err != nil {
			return 0, err
		}
		return 0, io.EOF
	}
	r.size += int64(len(data))
	if r.size > r.expectedSize {
		return 0, errors.New("原件长度超过元数据")
	}
	r.digest.Write(data)
	// Validate EOF before releasing the last bytes, so a truncated terminator cannot look complete over HTTP.
	if r.size == r.expectedSize {
		ending, readErr := r.readFrame()
		if readErr != nil {
			return 0, readErr
		}
		if len(ending) != 0 {
			return 0, errors.New("原件结束帧缺失")
		}
		if err = r.finish(); err != nil {
			return 0, err
		}
	}
	r.buffer = data
	return r.Read(p)
}
func (r *orderMediaReader) readFrame() ([]byte, error) {
	var header [4]byte
	if _, err := io.ReadFull(r.file, header[:]); err != nil {
		return nil, errors.New("原件缺少认证结束帧")
	}
	size := binary.BigEndian.Uint32(header[:])
	if size > orderMediaChunk {
		return nil, errors.New("原件帧长度无效")
	}
	nonce := make([]byte, r.aead.NonceSize())
	sealed := make([]byte, int(size)+r.aead.Overhead())
	if _, err := io.ReadFull(r.file, nonce); err != nil {
		return nil, err
	}
	if _, err := io.ReadFull(r.file, sealed); err != nil {
		return nil, err
	}
	data, err := r.aead.Open(nil, nonce, sealed, mediaAAD(r.id, r.index, size))
	if err != nil {
		return nil, errors.New("原件认证失败")
	}
	r.index++
	return data, nil
}
func (r *orderMediaReader) finish() error {
	var extra [1]byte
	n, err := r.file.Read(extra[:])
	if n != 0 || err != io.EOF {
		return errors.New("原件结束后存在多余内容")
	}
	if r.size != r.expectedSize || hex.EncodeToString(r.digest.Sum(nil)) != r.expectedHash {
		return errors.New("原件长度或摘要不匹配")
	}
	r.done = true
	return nil
}
func (m *orderMediaStore) remove(id string) error {
	path, err := m.path(id)
	if err != nil {
		return err
	}
	err = os.Remove(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

func clearMediaDeadlines(w http.ResponseWriter, r *http.Request) {
	controller := http.NewResponseController(w)
	_ = controller.SetReadDeadline(time.Time{})
	_ = controller.SetWriteDeadline(time.Time{})
}
func (s *Service) registerOrderUploadRoutes(protected func(string, func(http.ResponseWriter, *http.Request, Actor))) {
	protected("POST /api/v38/order-uploads", s.uploadOrderMedia)
	protected("DELETE /api/v38/order-uploads/{uploadId}", s.cancelOrderUpload)
}
func (s *Service) uploadOrderMedia(w http.ResponseWriter, r *http.Request, actor Actor) {
	clearMediaDeadlines(w, r)
	if err := roles(actor, "admin", "dispatcher", "customer"); err != nil {
		writeFailure(w, err)
		return
	}
	if s.orderMedia == nil {
		writeFailure(w, fail(503, "media_store_unavailable", "当前存储未配置私有原件目录"))
		return
	}
	key := r.Header.Get("Idempotency-Key")
	if key == "" || len(key) > 128 {
		writeFailure(w, fail(422, "idempotency_key_required", "每个原件需要1—128字符的Idempotency-Key"))
		return
	}
	name, err := url.PathUnescape(r.Header.Get("X-File-Name"))
	if err != nil {
		writeFailure(w, fail(422, "invalid_media_name", "文件名编码无效"))
		return
	}
	contentType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil {
		writeFailure(w, fail(422, "unsupported_media", "请选择图片或视频原件"))
		return
	}
	if err = validOrderMediaName(name, contentType); err != nil {
		writeFailure(w, err)
		return
	}
	id := randomID("upload_")
	size, sum, err := s.orderMedia.put(r.Context(), id, r.Body)
	if err != nil {
		writeFailure(w, err)
		return
	}
	keep := false
	defer func() {
		if !keep {
			_ = s.orderMedia.remove(id)
		}
	}()
	upload := OrderUpload{ID: id, Name: name, MIME: contentType, Size: size, SHA256: sum, ActorID: actor.ID, CompanyID: actor.CompanyID, AuthVersion: actor.AuthVersion, RequestKey: key, CreatedAt: nowString(s.now())}
	reader, err := s.orderMedia.open(r.Context(), id, size, sum)
	if err == nil {
		err = validateOrderMediaReader(name, contentType, reader, size)
		reader.Close()
	}
	if err != nil {
		writeFailure(w, err)
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	current, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	if current.CompanyID != actor.CompanyID {
		writeFailure(w, fail(401, "unauthenticated", "账号所属企业已变化"))
		return
	}
	if err = r.Context().Err(); err != nil {
		writeFailure(w, err)
		return
	}
	for _, old := range s.state.OrderUploads {
		if old.ActorID == actor.ID && old.AuthVersion == actor.AuthVersion && old.CompanyID == actor.CompanyID && old.RequestKey == key {
			if old.Name != name || old.MIME != contentType || old.Size != size || old.SHA256 != sum {
				writeFailure(w, fail(409, "idempotency_conflict", "原件请求键已用于不同内容"))
				return
			}
			if old.Canceled {
				writeFailure(w, fail(409, "upload_canceled", "原件已取消，请使用新的请求键"))
				return
			}
			writeJSON(w, 201, old.receipt())
			return
		}
	}
	next, err := cloneUploadState(s.state)
	if err == nil {
		next.OrderUploads[id] = upload
		s.appendAudit(&next, actor, "order_upload", id, "success")
		err = s.saveUploadState(next)
	}
	if err != nil {
		writeFailure(w, err)
		return
	}
	keep = true
	writeJSON(w, 201, upload.receipt())
}
func cloneUploadState(state State) (State, error) {
	raw, err := json.Marshal(state)
	if err != nil {
		return State{}, err
	}
	var next State
	err = json.Unmarshal(raw, &next)
	if next.OrderUploads == nil {
		next.OrderUploads = map[string]OrderUpload{}
	}
	return next, err
}
func (s *Service) saveUploadState(next State) error {
	raw, err := json.Marshal(next)
	if err == nil {
		err = s.persistence.Save(raw)
	}
	if err == nil {
		s.state = next
	}
	return err
}
func (s *Service) cancelOrderUpload(w http.ResponseWriter, r *http.Request, actor Actor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	actor, err := s.currentActorLocked(actor)
	if err != nil {
		writeFailure(w, err)
		return
	}
	upload, ok := s.state.OrderUploads[r.PathValue("uploadId")]
	if !ok || upload.ActorID != actor.ID || upload.CompanyID != actor.CompanyID || upload.AuthVersion != actor.AuthVersion {
		writeFailure(w, fail(404, "not_found", "原件不存在或不属于当前账号"))
		return
	}
	if upload.OrderID != "" {
		writeFailure(w, fail(409, "upload_bound", "已绑定工单的原件不能取消"))
		return
	}
	if !upload.Canceled {
		next, err := cloneUploadState(s.state)
		if err != nil {
			writeFailure(w, err)
			return
		}
		upload.Canceled = true
		next.OrderUploads[upload.ID] = upload
		s.appendAudit(&next, actor, "order_upload_cancel", upload.ID, "success")
		if err = s.saveUploadState(next); err != nil {
			writeFailure(w, err)
			return
		}
	}
	if s.orderMedia != nil {
		if err = s.orderMedia.remove(upload.ID); err != nil {
			writeFailure(w, err)
			return
		}
	}
	writeJSON(w, 200, map[string]bool{"ok": true})
}

func (s *Service) bindOrderUpload(state *State, actor Actor, orderID string, input OrderMediaInput, now time.Time) (Evidence, error) {
	upload, ok := state.OrderUploads[input.UploadID]
	if !ok || upload.Canceled || upload.ActorID != actor.ID || upload.CompanyID != actor.CompanyID || upload.AuthVersion != actor.AuthVersion {
		return Evidence{}, fail(404, "not_found", "原件不存在或不属于当前账号授权")
	}
	if upload.OrderID != "" {
		return Evidence{}, fail(409, "upload_bound", "原件已经绑定工单")
	}
	if input.DataBase64 != "" || input.Name != "" && input.Name != upload.Name || input.MIME != "" && input.MIME != upload.MIME || input.Size != 0 && input.Size != upload.Size || input.SHA256 != "" && input.SHA256 != upload.SHA256 {
		return Evidence{}, fail(422, "upload_metadata_mismatch", "原件元数据不匹配")
	}
	if s.orderMedia == nil {
		return Evidence{}, errors.New("私有原件存储缺失")
	}
	path, err := s.orderMedia.path(upload.ID)
	if err != nil {
		return Evidence{}, err
	}
	if _, err = os.Stat(path); err != nil {
		return Evidence{}, err
	}
	upload.OrderID = orderID
	state.OrderUploads[upload.ID] = upload
	kind := "image"
	if strings.HasPrefix(upload.MIME, "video/") {
		kind = "video"
	}
	return Evidence{ID: randomID("file_"), Name: upload.Name, Kind: kind, MIME: upload.MIME, UploaderID: actor.ID, CreatedAt: nowString(now), Stage: "pending_intake", Public: true, SHA256: upload.SHA256, Size: upload.Size, BlobID: upload.ID}, nil
}

func liveOrderMedia(state State) map[string]bool {
	refs := map[string]bool{}
	for _, order := range state.Orders {
		for _, file := range order.Evidence {
			if file.BlobID != "" && !file.Deleted {
				refs[file.BlobID] = true
			}
		}
	}
	for _, upload := range state.OrderUploads {
		if !upload.Canceled && upload.OrderID == "" {
			refs[upload.ID] = true
		}
	}
	return refs
}
func (s *Service) cleanupRemovedOrderMedia(previous, next State) error {
	if s.orderMedia == nil {
		return nil
	}
	live := liveOrderMedia(next)
	var cleanupErr error
	for id := range liveOrderMedia(previous) {
		if !live[id] {
			cleanupErr = errors.Join(cleanupErr, s.orderMedia.remove(id))
		}
	}
	return cleanupErr
}

// Only the default file store has an exclusive process writer lock covering this directory.
func (s *Service) cleanupAbandonedOrderMedia() error {
	persistence, ok := s.persistence.(*FilePersistence)
	if !ok || s.orderMedia == nil || filepath.Clean(s.orderMedia.dir) != filepath.Clean(filepath.Join(persistence.dir, "order-media")) {
		return nil
	}
	entries, err := os.ReadDir(s.orderMedia.dir)
	if err != nil {
		return err
	}
	live := liveOrderMedia(s.state)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasPrefix(name, ".upload-") {
			if err = os.Remove(filepath.Join(s.orderMedia.dir, name)); err != nil {
				return err
			}
		} else if strings.HasSuffix(name, ".enc") {
			id := strings.TrimSuffix(name, ".enc")
			if _, err = s.orderMedia.path(id); err == nil && !live[id] {
				if err = s.orderMedia.remove(id); err != nil {
					return err
				}
			}
		}
	}
	return nil
}
