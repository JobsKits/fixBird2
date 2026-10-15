package payment

import "context"

type Provider string

const (
	ProviderWeChat  Provider = "wechat"
	ProviderAlipay  Provider = "alipay"
	ProviderAggrPay Provider = "aggregate"
)

type IntentRequest struct {
	OrderID     string
	AmountCents int64
	Currency    string
	CallbackURL string
}

type Intent struct {
	Provider    Provider `json:"provider"`
	Reference   string   `json:"reference"`
	RedirectURL string   `json:"redirectUrl"`
}

type Gateway interface {
	Provider() Provider
	CreateIntent(context.Context, IntentRequest) (Intent, error)
}

type NotConfigured struct {
	PaymentProvider Provider
}

func (g NotConfigured) Provider() Provider {
	return g.PaymentProvider
}

func (g NotConfigured) CreateIntent(context.Context, IntentRequest) (Intent, error) {
	return Intent{}, ErrProviderNotConfigured
}
