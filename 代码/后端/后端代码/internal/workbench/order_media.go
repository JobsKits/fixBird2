// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"image"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode"
)

type OrderMediaInput struct {
	UploadID   string `json:"uploadId,omitempty"`
	Name       string `json:"name,omitempty"`
	MIME       string `json:"mime,omitempty"`
	Size       int64  `json:"size,omitempty"`
	SHA256     string `json:"sha256,omitempty"`
	DataBase64 string `json:"dataBase64,omitempty"`
}

// The cloned aggregate binds every reference together with the new order.
func (s *Service) initialOrderMedia(state *State, actor Actor, orderID string, inputs []OrderMediaInput, now time.Time) ([]Evidence, error) {
	files := []Evidence{}
	for _, input := range inputs {
		if input.UploadID != "" {
			file, err := s.bindOrderUpload(state, actor, orderID, input, now)
			if err != nil {
				return nil, err
			}
			files = append(files, file)
			continue
		}
		data, err := base64.StdEncoding.Strict().DecodeString(input.DataBase64)
		if err != nil {
			return nil, fail(422, "invalid_media", "请选择有效设备图片或视频原件")
		}
		if err = validateOrderMediaReader(input.Name, input.MIME, bytes.NewReader(data), int64(len(data))); err != nil {
			return nil, err
		}
		sum := sha256.Sum256(data)
		kind := "image"
		if strings.HasPrefix(input.MIME, "video/") {
			kind = "video"
		}
		files = append(files, Evidence{ID: randomID("file_"), Name: input.Name, Kind: kind, MIME: input.MIME, Data: input.DataBase64, UploaderID: actor.ID, CreatedAt: nowString(now), Stage: "pending_intake", Public: true, SHA256: hex.EncodeToString(sum[:]), Size: int64(len(data))})
	}
	return files, nil
}
func validOrderMediaName(name, mime string) error {
	if !validPersonalText(name, 1, 180) || strings.ContainsAny(name, "/\\") || strings.IndexFunc(name, unicode.IsControl) >= 0 {
		return fail(422, "invalid_media_name", "请使用不含路径或控制字符的文件名（最多180字符）")
	}
	switch mime {
	case "image/png", "image/jpeg", "image/gif", "image/webp", "video/mp4", "video/quicktime", "video/webm":
		return nil
	}
	return fail(422, "unsupported_media", "支持PNG/JPEG/GIF/WebP和MP4/WebM/QuickTime原件")
}
func validateOrderMediaReader(name, mime string, src io.Reader, size int64) error {
	if err := validOrderMediaName(name, mime); err != nil {
		return err
	}
	if size < 1 {
		return fail(422, "invalid_media", "原件内容为空")
	}
	reader := bufio.NewReaderSize(src, orderMediaChunk)
	prefix, _ := reader.Peek(int(min(size, 512)))
	detected := http.DetectContentType(prefix)
	valid := false
	switch mime {
	case "image/png", "image/jpeg", "image/gif":
		config, _, err := image.DecodeConfig(reader)
		valid = err == nil && config.Width > 0 && config.Height > 0 && detected == mime
	case "image/webp":
		valid = len(prefix) >= 16 && string(prefix[:4]) == "RIFF" && string(prefix[8:12]) == "WEBP" && http.DetectContentType(prefix) == mime
	case "video/mp4", "video/quicktime":
		if len(prefix) >= 16 && string(prefix[4:8]) == "ftyp" && (mime == "video/quicktime") == (string(prefix[8:12]) == "qt  ") {
			valid = validOrderMP4(reader, size)
		}
	case "video/webm":
		if len(prefix) >= 16 && bytes.HasPrefix(prefix, []byte{0x1a, 0x45, 0xdf, 0xa3}) && bytes.Contains(prefix, []byte("webm")) {
			found, err := scanMediaMarkers(reader, []string{string([]byte{0x18, 0x53, 0x80, 0x67}), string([]byte{0x16, 0x54, 0xae, 0x6b}), string([]byte{0x1f, 0x43, 0xb6, 0x75})})
			valid = err == nil && found[0] && found[1] && found[2]
		}
	}
	if !valid {
		return fail(422, "invalid_media", "文件内容与类型不匹配或视频容器不完整")
	}
	// Reading through authenticated EOF detects missing/tampered frames without retaining the original.
	if _, err := io.Copy(io.Discard, reader); err != nil {
		return err
	}
	return nil
}
func scanMediaMarkers(reader io.Reader, markers []string) ([]bool, error) {
	found := make([]bool, len(markers))
	buffer := make([]byte, orderMediaChunk+8)
	carry := 0
	for {
		n, err := reader.Read(buffer[carry:])
		total := carry + n
		for i, marker := range markers {
			found[i] = found[i] || bytes.Contains(buffer[:total], []byte(marker))
		}
		carry = min(total, 8)
		copy(buffer[:carry], buffer[total-carry:total])
		if err == io.EOF {
			return found, nil
		}
		if err != nil {
			return nil, err
		}
	}
}
func validOrderMP4(reader io.Reader, total int64) bool {
	seen := map[string]bool{}
	for offset := int64(0); offset < total; {
		var header [16]byte
		if total-offset < 8 {
			return false
		}
		if _, err := io.ReadFull(reader, header[:8]); err != nil {
			return false
		}
		size := uint64(binary.BigEndian.Uint32(header[:4]))
		kind := string(header[4:8])
		head := uint64(8)
		if size == 1 {
			if total-offset < 16 {
				return false
			}
			if _, err := io.ReadFull(reader, header[8:]); err != nil {
				return false
			}
			size = binary.BigEndian.Uint64(header[8:])
			head = 16
		} else if size == 0 {
			size = uint64(total - offset)
		}
		if size < head || size > uint64(total-offset) {
			return false
		}
		limited := &io.LimitedReader{R: reader, N: int64(size - head)}
		switch kind {
		case "ftyp":
			seen[kind] = size >= 16
		case "mdat":
			seen[kind] = size > head
		case "moov":
			found, err := scanMediaMarkers(limited, []string{"trak", "vide"})
			if err != nil {
				return false
			}
			seen[kind] = len(found) == 2 && found[0] && found[1]
		}
		if _, err := io.Copy(io.Discard, limited); err != nil || limited.N != 0 {
			return false
		}
		offset += int64(size)
	}
	return seen["ftyp"] && seen["moov"] && seen["mdat"]
}
func validOrderVideo(mime string, data []byte) bool {
	return validateOrderMediaReader("video", mime, bytes.NewReader(data), int64(len(data))) == nil
}
