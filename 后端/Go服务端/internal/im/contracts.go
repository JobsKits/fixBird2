// Package im 仅保留下一版本的独立聊天边界，不注册路由或提供运行实现。
package im

import "context"

// BusinessReference 只传关联标识，避免聊天依赖订单领域服务。
type BusinessReference struct {
	Type string
	ID   string
}

type OpenConversationInput struct {
	ActorID        string
	ParticipantIDs []string
	Business       *BusinessReference
}

type Conversation struct {
	ID             string
	ParticipantIDs []string
	Business       *BusinessReference
}

// Gateway 由应用层注入；下一版本再确定消息、连接与存储接口。
type Gateway interface {
	OpenConversation(context.Context, OpenConversationInput) (Conversation, error)
}
