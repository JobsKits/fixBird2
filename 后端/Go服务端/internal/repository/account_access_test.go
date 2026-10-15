package repository_test

import (
	"context"
	"errors"
	"repair-platform/internal/domain"
	"repair-platform/internal/identity"
	"repair-platform/internal/repository"
	"repair-platform/internal/service"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestAccountAccessContract(t *testing.T) {
	for _, backend := range []string{"memory", "tidb-pessimistic", "tidb-optimistic"} {
		t.Run(backend, func(t *testing.T) {
			ctx := context.Background()
			var store identity.Store = identity.NewMemory()
			if backend != "memory" {
				db := testTiDB(t, strings.TrimPrefix(backend, "tidb-")).(*repository.TiDB)
				store = identity.NewTiDB(db.DB())
			}
			accounts, err := identity.NewService(store, time.Hour)
			if err != nil {
				t.Fatal(err)
			}
			if err := accounts.BootstrapAdmin(ctx, "", ""); err != nil {
				t.Fatal(err)
			}
			admin, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "admin"})
			if err != nil {
				t.Fatal(err)
			}
			created, err := accounts.AddAccount(ctx, admin.User, identity.AccountInput{Username: "contract-operator", Password: "contract-password-long", DisplayName: "普通账号", Role: domain.RoleOperator})
			if err != nil {
				t.Fatal(err)
			}
			op, err := accounts.Login(ctx, identity.LoginInput{Username: created.User.Username, Password: "contract-password-long"})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Accounts(ctx, op.User, ""); !errors.Is(err, service.ErrForbidden) {
				t.Fatal("operator account management", err)
			}
			if _, err := accounts.AddAccount(ctx, op.User, identity.AccountInput{}); !errors.Is(err, service.ErrForbidden) {
				t.Fatal("operator privilege escalation", err)
			}
			rows, err := accounts.Accounts(ctx, admin.User, "")
			if err != nil || len(rows) != 2 {
				t.Fatal("persistent account list", len(rows), err)
			}
			if err := accounts.SetAccountStatus(ctx, admin.User, op.User.Username, "disabled"); err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Authenticate(ctx, op.Token); !errors.Is(err, identity.ErrUnauthenticated) {
				t.Fatal("disabled session", err)
			}
			if _, err := accounts.Login(ctx, identity.LoginInput{Username: op.User.Username, Password: "contract-password-long"}); !errors.Is(err, identity.ErrAccountDisabled) {
				t.Fatal("disabled login", err)
			}
			if err := accounts.SetAccountStatus(ctx, admin.User, op.User.Username, "active"); err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Authenticate(ctx, op.Token); !errors.Is(err, identity.ErrUnauthenticated) {
				t.Fatal("unban resurrected old token", err)
			}
			op, err = accounts.Login(ctx, identity.LoginInput{Username: op.User.Username, Password: "contract-password-long"})
			if err != nil {
				t.Fatal(err)
			}
			if err := accounts.ChangeOwnPassword(ctx, op.User, "wrong-password", "own-password-long"); !errors.Is(err, identity.ErrCredentials) {
				t.Fatal("old password unchecked", err)
			}
			code, err := accounts.NewRecoveryCode(ctx, op.User)
			if err != nil {
				t.Fatal(err)
			}
			var succeeded atomic.Int64
			var group sync.WaitGroup
			for i := 0; i < 2; i++ {
				group.Add(1)
				go func() {
					defer group.Done()
					err := accounts.ResetPassword(ctx, identity.PasswordResetInput{Username: op.User.Username, RecoveryCode: code, Password: "recovered-password-long"})
					if err == nil {
						succeeded.Add(1)
					} else if !errors.Is(err, identity.ErrCredentials) && !errors.Is(err, repository.ErrRetryable) {
						t.Error(err)
					}
				}()
			}
			group.Wait()
			if succeeded.Load() != 1 {
				t.Fatal("recovery code consumed more than once", succeeded.Load())
			}
			if _, err := accounts.Authenticate(ctx, op.Token); !errors.Is(err, identity.ErrUnauthenticated) {
				t.Fatal("reset did not revoke sessions", err)
			}
			if _, err := accounts.Login(ctx, identity.LoginInput{Username: op.User.Username, Password: "recovered-password-long"}); err != nil {
				t.Fatal(err)
			}
			if err := accounts.ResetAccountPassword(ctx, admin.User, "admin", "new-primary-password"); err != nil {
				t.Fatal(err)
			}
			if err := accounts.BootstrapAdmin(ctx, "", ""); err != nil {
				t.Fatal(err)
			}
			if _, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "admin"}); err == nil {
				t.Fatal("bootstrap overwrote changed password")
			}
			if _, err := accounts.Login(ctx, identity.LoginInput{Username: "admin", Password: "new-primary-password"}); err != nil {
				t.Fatal(err)
			}
		})
	}
}
