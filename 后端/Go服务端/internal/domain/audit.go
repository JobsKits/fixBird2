package domain

import "context"

type auditActorKey struct{}

func WithAuditActor(ctx context.Context, actor Actor) context.Context {
	return context.WithValue(ctx, auditActorKey{}, actor.ID)
}
func AuditActorID(ctx context.Context) string {
	value, _ := ctx.Value(auditActorKey{}).(string)
	if value == "" {
		return "system"
	}
	return value
}
