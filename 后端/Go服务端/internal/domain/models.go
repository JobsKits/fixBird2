package domain

import "time"

type Role string

const (
	RoleCustomer Role = "customer"
	RoleWorker   Role = "worker"
	RoleAdmin    Role = "admin"
	RoleOperator Role = "operator"
)

type OrderStatus string

const (
	StatusPendingWorker OrderStatus = "pending_worker"
	StatusAccepted      OrderStatus = "accepted"
	StatusArrived       OrderStatus = "arrived"
	StatusQuotePending  OrderStatus = "quote_pending"
	StatusInService     OrderStatus = "in_service"
	StatusAwaitingPay   OrderStatus = "awaiting_payment"
	StatusCompleted     OrderStatus = "completed"
	StatusCancelled     OrderStatus = "cancelled"
)

type PaymentStatus string

const (
	PaymentNotStarted PaymentStatus = "not_started"
	PaymentPending    PaymentStatus = "pending"
	PaymentDemoPaid   PaymentStatus = "demo_paid"
)

type SettlementStatus string

const (
	SettlementPendingManual SettlementStatus = "pending_manual"
	SettlementManuallyPaid  SettlementStatus = "manually_paid"
)

type Actor struct {
	ID   string
	Role Role
	Demo bool
}

type Order struct {
	ID                string        `json:"id"`
	CustomerID        string        `json:"customerId"`
	WorkerID          string        `json:"workerId"`
	Category          string        `json:"category"`
	Equipment         string        `json:"equipment"`
	Issue             string        `json:"issue"`
	Address           string        `json:"address"`
	ScheduledAt       string        `json:"scheduledAt"`
	Status            OrderStatus   `json:"status"`
	PaymentStatus     PaymentStatus `json:"paymentStatus"`
	QuotedAmountCents int64         `json:"quotedAmountCents"`
	PlatformFeeCents  int64         `json:"platformFeeCents"`
	WorkerShareCents  int64         `json:"workerShareCents"`
	ProfitRuleVersion string        `json:"profitRuleVersion"`
	CreatedAt         time.Time     `json:"createdAt"`
	UpdatedAt         time.Time     `json:"updatedAt"`
}

type CreateOrderInput struct {
	Category    string `json:"category"`
	Equipment   string `json:"equipment"`
	Issue       string `json:"issue"`
	Address     string `json:"address"`
	ScheduledAt string `json:"scheduledAt"`
}

type Worker struct {
	ID           string   `json:"id"`
	DisplayName  string   `json:"displayName"`
	ServiceAreas []string `json:"serviceAreas"`
	Skills       []string `json:"skills"`
	Status       string   `json:"status"`
}

type Settlement struct {
	ID                string           `json:"id"`
	OrderID           string           `json:"orderId"`
	WorkerID          string           `json:"workerId"`
	GrossAmountCents  int64            `json:"grossAmountCents"`
	PlatformFeeCents  int64            `json:"platformFeeCents"`
	WorkerShareCents  int64            `json:"workerShareCents"`
	ProfitRuleVersion string           `json:"profitRuleVersion"`
	Status            SettlementStatus `json:"status"`
	CreatedAt         time.Time        `json:"createdAt"`
}

type Dashboard struct {
	TotalOrders        int   `json:"totalOrders"`
	PendingOrders      int   `json:"pendingOrders"`
	ActiveOrders       int   `json:"activeOrders"`
	CompletedOrders    int   `json:"completedOrders"`
	PendingSettlements int   `json:"pendingSettlements"`
	GrossAmountCents   int64 `json:"grossAmountCents"`
	PlatformFeeCents   int64 `json:"platformFeeCents"`
	WorkerShareCents   int64 `json:"workerShareCents"`
}

type PaymentIntentInput struct {
	OrderID  string `json:"orderId"`
	Provider string `json:"provider"`
}
