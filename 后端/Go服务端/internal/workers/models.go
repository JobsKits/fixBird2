package workers

import (
	"errors"
	"time"

	"repair-platform/internal/domain"
)

const MaxImageBytes int64 = 5 << 20

var (
	ErrNotApproved      = errors.New("worker application is not approved")
	ErrRevisionConflict = errors.New("application revision has changed")
	ErrImageTooLarge    = errors.New("image exceeds 5 MiB")
)

type Application struct {
	ID           string     `json:"id"`
	WorkerID     string     `json:"workerId"`
	DisplayName  string     `json:"displayName"`
	ContactPhone string     `json:"contactPhone"`
	ServiceAreas []string   `json:"serviceAreas"`
	Skills       []string   `json:"skills"`
	Bio          string     `json:"bio"`
	AssetIDs     []string   `json:"assetIds"`
	Status       string     `json:"status"`
	Revision     int64      `json:"revision"`
	ReviewNote   string     `json:"reviewNote"`
	ReviewedBy   string     `json:"reviewedBy"`
	ReviewedAt   *time.Time `json:"reviewedAt"`
	CreatedAt    time.Time  `json:"createdAt"`
	UpdatedAt    time.Time  `json:"updatedAt"`
}

type SubmitInput struct {
	DisplayName      string   `json:"displayName"`
	ContactPhone     string   `json:"contactPhone"`
	ServiceAreas     []string `json:"serviceAreas"`
	Skills           []string `json:"skills"`
	Bio              string   `json:"bio"`
	AssetIDs         []string `json:"assetIds"`
	ExpectedRevision int64    `json:"expectedRevision"`
}

type ReviewInput struct {
	Decision         string `json:"decision"`
	Note             string `json:"note"`
	ExpectedRevision int64  `json:"expectedRevision"`
}

type Asset struct {
	ID        string    `json:"id"`
	OwnerID   string    `json:"-"`
	MIMEType  string    `json:"mimeType"`
	SizeBytes int64     `json:"sizeBytes"`
	CreatedAt time.Time `json:"createdAt"`
}

type ListQuery struct {
	Limit  int
	Before *domain.Cursor
	Status string
}
