package service

import (
	"fmt"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"repair-platform/internal/domain"
)

func validateIdentifier(id string) error {
	if len(id) < 1 || len(id) > 64 {
		return fmt.Errorf("%w: identifier must be 1..64 ASCII characters", ErrInvalidInput)
	}
	for _, character := range id {
		if !(character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z' || character >= '0' && character <= '9' || character == '-' || character == '_') {
			return fmt.Errorf("%w: invalid identifier", ErrInvalidInput)
		}
	}
	return nil
}

func validateActor(actor domain.Actor) error {
	if actor.Role != domain.RoleCustomer && actor.Role != domain.RoleWorker && actor.Role != domain.RoleAdmin && actor.Role != domain.RoleOperator {
		return ErrForbidden
	}
	return validateIdentifier(actor.ID)
}

func validateKey(key string) error {
	if len(key) > 128 {
		return fmt.Errorf("%w: Idempotency-Key exceeds 128 characters", ErrInvalidInput)
	}
	for _, character := range key {
		if character < 33 || character > 126 {
			return fmt.Errorf("%w: invalid Idempotency-Key", ErrInvalidInput)
		}
	}
	return nil
}

func normalizeInput(input domain.CreateOrderInput) (domain.CreateOrderInput, error) {
	fields := []struct {
		name  string
		value *string
		max   int
	}{{"category", &input.Category, 120}, {"equipment", &input.Equipment, 160}, {"issue", &input.Issue, 4000}, {"address", &input.Address, 500}}
	for _, field := range fields {
		*field.value = strings.TrimSpace(*field.value)
		if !utf8.ValidString(*field.value) || utf8.RuneCountInString(*field.value) < 1 || utf8.RuneCountInString(*field.value) > field.max {
			return input, fmt.Errorf("%w: %s must be 1..%d characters", ErrInvalidInput, field.name, field.max)
		}
		for _, character := range *field.value {
			if unicode.IsControl(character) && character != '\n' && character != '\t' {
				return input, fmt.Errorf("%w: invalid %s", ErrInvalidInput, field.name)
			}
		}
	}
	known := false
	for _, category := range domain.Categories {
		if category == input.Category {
			known = true
			break
		}
	}
	if !known {
		return input, fmt.Errorf("%w: unsupported category", ErrInvalidInput)
	}
	input.ScheduledAt = strings.TrimSpace(input.ScheduledAt)
	if input.ScheduledAt != "" {
		value, err := time.Parse(time.RFC3339, input.ScheduledAt)
		if err != nil {
			return input, fmt.Errorf("%w: scheduledAt requires RFC3339 with timezone or an empty string", ErrInvalidInput)
		}
		input.ScheduledAt = value.UTC().Format(time.RFC3339)
	}
	return input, nil
}
