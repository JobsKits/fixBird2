package domain

import (
	"errors"
	"math"
	"time"
)

const (
	MaxQuoteCents     int64 = 100_000_000
	ProfitRuleVersion       = "demo-worker85-half-up-v1"
	DefaultPageSize         = 100
	MaxPageSize             = 200
)

var ErrAmountOverflow = errors.New("amount is outside the supported range")

var Categories = []string{"家电维修", "家电清洗", "家电安装", "水电维修", "管道疏通", "防水补漏", "家具门窗", "房屋修缮", "数码维修"}

// SplitDemoAmount keeps the rounded worker share authoritative; the fee is the remainder.
func SplitDemoAmount(amount int64) (workerShare, platformFee int64, err error) {
	if amount < 1 || amount > MaxQuoteCents {
		return 0, 0, ErrAmountOverflow
	}
	workerShare = (amount*85 + 50) / 100
	return workerShare, amount - workerShare, nil
}

func AddCents(total, amount int64) (int64, error) {
	if amount < 0 || total < 0 || amount > math.MaxInt64-total {
		return 0, ErrAmountOverflow
	}
	return total + amount, nil
}

type Cursor struct {
	CreatedAt time.Time `json:"createdAt"`
	ID        string    `json:"id"`
}

type ListQuery struct {
	Actor         Actor
	Limit         int
	Before        *Cursor
	Status        OrderStatus
	OwnWorkerOnly bool
}

func (q ListQuery) PageSize() int {
	if q.Limit < 1 {
		return DefaultPageSize
	}
	if q.Limit > MaxPageSize {
		return MaxPageSize
	}
	return q.Limit
}

func VisibleTo(order Order, actor Actor) bool {
	switch actor.Role {
	case RoleAdmin, RoleOperator:
		return true
	case RoleCustomer:
		return order.CustomerID == actor.ID
	case RoleWorker:
		if actor.Demo && order.CustomerID != "customer-demo" {
			return false
		}
		return order.Status == StatusPendingWorker || order.WorkerID == actor.ID
	default:
		return false
	}
}

func BeforeCursor(createdAt time.Time, id string, cursor *Cursor) bool {
	return cursor == nil || createdAt.Before(cursor.CreatedAt) || (createdAt.Equal(cursor.CreatedAt) && id < cursor.ID)
}
