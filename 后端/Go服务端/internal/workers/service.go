package workers

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"repair-platform/internal/domain"
	"repair-platform/internal/service"
)

type Service struct {
	store    Store
	assetDir string
}

func NewService(store Store, assetDir string) (*Service, error) {
	if strings.TrimSpace(assetDir) == "" {
		return nil, fmt.Errorf("private asset directory is required")
	}
	root, err := filepath.Abs(assetDir)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(root, 0700); err != nil {
		return nil, err
	}
	if err := os.Chmod(root, 0700); err != nil {
		return nil, err
	}
	return &Service{store: store, assetDir: root}, nil
}

func NewID(prefix string) string {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		panic("system randomness unavailable")
	}
	return prefix + "_" + hex.EncodeToString(value)
}

func (s *Service) CanAccept(ctx context.Context, id string) (bool, error) {
	return s.store.CanAccept(ctx, id)
}
func (s *Service) Ready(ctx context.Context) error { return s.store.Ready(ctx) }

func (s *Service) Get(ctx context.Context, actor domain.Actor) (Application, error) {
	if actor.Role != domain.RoleWorker {
		return Application{}, service.ErrForbidden
	}
	return s.store.GetApplication(ctx, actor.ID)
}

func text(value string, maximum int, required bool) (string, error) {
	value = strings.TrimSpace(value)
	if !utf8.ValidString(value) || utf8.RuneCountInString(value) > maximum || (required && value == "") {
		return "", service.ErrInvalidInput
	}
	for _, r := range value {
		if unicode.IsControl(r) && r != '\n' && r != '\t' {
			return "", service.ErrInvalidInput
		}
	}
	return value, nil
}

func values(input []string, maximum int) ([]string, error) {
	if len(input) == 0 || len(input) > maximum {
		return nil, service.ErrInvalidInput
	}
	result := make([]string, 0, len(input))
	seen := make(map[string]bool)
	for _, value := range input {
		normalized, err := text(value, 120, true)
		if err != nil || seen[normalized] {
			return nil, service.ErrInvalidInput
		}
		seen[normalized] = true
		result = append(result, normalized)
	}
	return result, nil
}

func (s *Service) Submit(ctx context.Context, actor domain.Actor, input SubmitInput) (Application, error) {
	if actor.Role != domain.RoleWorker {
		return Application{}, service.ErrForbidden
	}
	var err error
	if input.ExpectedRevision < 0 || input.ExpectedRevision >= 1_000_000 {
		return Application{}, service.ErrInvalidInput
	}
	if input.DisplayName, err = text(input.DisplayName, 120, true); err != nil {
		return Application{}, err
	}
	if input.ContactPhone, err = text(input.ContactPhone, 40, true); err != nil {
		return Application{}, err
	}
	if input.Bio, err = text(input.Bio, 2000, false); err != nil {
		return Application{}, err
	}
	if input.ServiceAreas, err = values(input.ServiceAreas, 20); err != nil {
		return Application{}, err
	}
	if input.Skills, err = values(input.Skills, 20); err != nil {
		return Application{}, err
	}
	if len(input.AssetIDs) == 0 || len(input.AssetIDs) > 6 {
		return Application{}, fmt.Errorf("%w: attach 1..6 qualification images", service.ErrInvalidInput)
	}
	seen := make(map[string]bool)
	for _, id := range input.AssetIDs {
		if !assetID.MatchString(id) || seen[id] {
			return Application{}, service.ErrInvalidInput
		}
		seen[id] = true
		asset, err := s.store.GetAsset(ctx, id)
		if err != nil {
			return Application{}, err
		}
		if asset.OwnerID != actor.ID {
			return Application{}, service.ErrForbidden
		}
	}
	now := time.Now().UTC().Truncate(time.Millisecond)
	return s.store.Submit(ctx, Application{ID: NewID("app"), WorkerID: actor.ID, DisplayName: input.DisplayName, ContactPhone: input.ContactPhone, ServiceAreas: input.ServiceAreas, Skills: input.Skills, Bio: input.Bio, AssetIDs: input.AssetIDs, CreatedAt: now, UpdatedAt: now}, input.ExpectedRevision)
}

func (s *Service) Review(ctx context.Context, actor domain.Actor, id string, input ReviewInput) (Application, error) {
	if actor.Role != domain.RoleAdmin {
		return Application{}, service.ErrForbidden
	}
	if !regexp.MustCompile(`^app_[a-f0-9]{32}$`).MatchString(id) || input.ExpectedRevision < 1 || (input.Decision != "approved" && input.Decision != "rejected") {
		return Application{}, service.ErrInvalidInput
	}
	var err error
	if input.Note, err = text(input.Note, 1000, input.Decision == "rejected"); err != nil {
		return Application{}, err
	}
	return s.store.Review(ctx, id, input, actor.ID, time.Now().UTC().Truncate(time.Millisecond))
}

func (s *Service) List(ctx context.Context, actor domain.Actor, query ListQuery) ([]Application, error) {
	if actor.Role != domain.RoleAdmin {
		return nil, service.ErrForbidden
	}
	if query.Status != "" && query.Status != "pending" && query.Status != "approved" && query.Status != "rejected" {
		return nil, service.ErrInvalidInput
	}
	if query.Limit < 1 || query.Limit > domain.MaxPageSize {
		return nil, service.ErrInvalidInput
	}
	return s.store.List(ctx, query)
}

var assetID = regexp.MustCompile(`^asset_[a-f0-9]{32}$`)

func (s *Service) Upload(ctx context.Context, actor domain.Actor, source io.Reader) (Asset, error) {
	if actor.Role != domain.RoleWorker {
		return Asset{}, service.ErrForbidden
	}
	payload, err := io.ReadAll(io.LimitReader(source, MaxImageBytes+1))
	if err != nil {
		return Asset{}, err
	}
	if int64(len(payload)) > MaxImageBytes {
		return Asset{}, ErrImageTooLarge
	}
	configuration, format, err := image.DecodeConfig(bytes.NewReader(payload))
	if err != nil || (format != "jpeg" && format != "png") || configuration.Width < 1 || configuration.Height < 1 || configuration.Width > 4096 || configuration.Height > 4096 || int64(configuration.Width)*int64(configuration.Height) > 16_000_000 {
		return Asset{}, fmt.Errorf("%w: image must be JPEG/PNG and at most 4096 pixels per side", service.ErrInvalidInput)
	}
	decoded, _, err := image.Decode(bytes.NewReader(payload))
	if err != nil {
		return Asset{}, service.ErrInvalidInput
	}
	// Re-encode to remove unneeded metadata and any appended non-image content.
	var normalized bytes.Buffer
	mimeType := "image/jpeg"
	if format == "png" {
		mimeType = "image/png"
		err = png.Encode(&normalized, decoded)
	} else {
		err = jpeg.Encode(&normalized, decoded, &jpeg.Options{Quality: 90})
	}
	if err != nil {
		return Asset{}, err
	}
	if int64(normalized.Len()) > MaxImageBytes {
		return Asset{}, ErrImageTooLarge
	}
	if err := ctx.Err(); err != nil {
		return Asset{}, err
	}
	asset := Asset{ID: NewID("asset"), OwnerID: actor.ID, MIMEType: mimeType, SizeBytes: int64(normalized.Len()), CreatedAt: time.Now().UTC().Truncate(time.Millisecond)}
	path := filepath.Join(s.assetDir, asset.ID)
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return Asset{}, err
	}
	_, writeErr := file.Write(normalized.Bytes())
	closeErr := file.Close()
	if writeErr != nil || closeErr != nil {
		_ = os.Remove(path)
		if writeErr != nil {
			return Asset{}, writeErr
		}
		return Asset{}, closeErr
	}
	if err := s.store.SaveAsset(ctx, asset); err != nil {
		_ = os.Remove(path)
		return Asset{}, err
	}
	return asset, nil
}

func (s *Service) ReadAsset(ctx context.Context, actor domain.Actor, id string) (Asset, []byte, error) {
	if !assetID.MatchString(id) {
		return Asset{}, nil, service.ErrInvalidInput
	}
	asset, err := s.store.GetAsset(ctx, id)
	if err != nil {
		return Asset{}, nil, err
	}
	if actor.Role != domain.RoleAdmin && (actor.Role != domain.RoleWorker || actor.ID != asset.OwnerID) {
		return Asset{}, nil, service.ErrForbidden
	}
	file, err := os.Open(filepath.Join(s.assetDir, id))
	if err != nil {
		return Asset{}, nil, err
	}
	defer file.Close()
	payload, err := io.ReadAll(io.LimitReader(file, MaxImageBytes+1))
	if err != nil {
		return Asset{}, nil, err
	}
	if int64(len(payload)) != asset.SizeBytes || asset.SizeBytes > MaxImageBytes {
		return Asset{}, nil, fmt.Errorf("private asset is incomplete")
	}
	return asset, payload, nil
}
