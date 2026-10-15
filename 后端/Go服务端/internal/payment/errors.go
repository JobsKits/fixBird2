package payment

import "errors"

var ErrProviderNotConfigured = errors.New("payment provider is not configured")

func NewRegistry() map[Provider]Gateway {
	return map[Provider]Gateway{
		ProviderWeChat:  NotConfigured{PaymentProvider: ProviderWeChat},
		ProviderAlipay:  NotConfigured{PaymentProvider: ProviderAlipay},
		ProviderAggrPay: NotConfigured{PaymentProvider: ProviderAggrPay},
	}
}
