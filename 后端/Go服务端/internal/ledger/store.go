package ledger

import "context"

// Store exposes append/read only. A journal can be corrected only by a separate reversal.
type Store interface {
	Ready(context.Context) error
	Append(context.Context, Journal) (Journal, error)
	Get(context.Context, string) (Journal, error)
	GetEvent(context.Context, string) (Journal, error)
	List(context.Context, Query) ([]Journal, error)
	Snapshot(context.Context, Query, int) ([]Journal, error)
	Summary(context.Context, Query) (Summary, error)
}

func sameFinancialEvent(previous, next Journal) bool { return previous.Fingerprint == next.Fingerprint }

func validateAgainstState(journal Journal, byEvent map[string]Journal, byID map[string]Journal, reversed map[string]string) error {
	if journal.Kind == KindCollection {
		return nil
	}
	if journal.Kind == KindPayout {
		collection, exists := byEvent[CollectionEventKey(journal.Mode, journal.OrderID)]
		if !exists || reversed[collection.ID] != "" || collection.CustomerID != journal.CustomerID || collection.WorkerID != journal.WorkerID ||
			collection.SettlementID != journal.SettlementID || collection.WorkerShareCents != journal.AmountCents {
			return ErrInvalidState
		}
		return nil
	}
	original, exists := byID[journal.ReversalOfID]
	if !exists {
		return ErrNotFound
	}
	if original.Kind == KindReversal || reversed[original.ID] != "" || original.Mode != journal.Mode || original.Channel != journal.Channel ||
		original.OrderID != journal.OrderID || original.CustomerID != journal.CustomerID || original.WorkerID != journal.WorkerID || original.SettlementID != journal.SettlementID ||
		original.AmountCents != journal.AmountCents || original.WorkerShareCents != journal.WorkerShareCents || original.PlatformFeeCents != journal.PlatformFeeCents || len(original.Entries) != len(journal.Entries) {
		return ErrInvalidState
	}
	for index, entry := range original.Entries {
		reversedEntry := journal.Entries[index]
		if entry.Account != reversedEntry.Account || entry.AmountCents != reversedEntry.AmountCents || entry.Direction == reversedEntry.Direction {
			return ErrInvalidState
		}
	}
	if original.Kind == KindCollection {
		payout, exists := byEvent[PayoutEventKey(original.Mode, original.SettlementID)]
		if exists && reversed[payout.ID] == "" {
			return ErrInvalidState
		}
	}
	return nil
}

func newSummary(mode string) Summary {
	return Summary{Mode: mode, Simulated: mode == ModeSimulated, Currency: "CNY", Scope: "filtered_movements"}
}

func addToSummary(summary *Summary, journal Journal, originalKind string) error {
	sign, kind := int64(1), journal.Kind
	if kind == KindReversal {
		sign, kind = -1, originalKind
	}
	var err error
	if summary.JournalCount, err = addCents(summary.JournalCount, 1); err != nil {
		return err
	}
	if kind == KindCollection {
		if summary.CollectedCents, err = addCents(summary.CollectedCents, sign*journal.AmountCents); err != nil {
			return err
		}
		if summary.WorkerAccruedCents, err = addCents(summary.WorkerAccruedCents, sign*journal.WorkerShareCents); err != nil {
			return err
		}
		if summary.PlatformRevenueCents, err = addCents(summary.PlatformRevenueCents, sign*journal.PlatformFeeCents); err != nil {
			return err
		}
	} else if kind == KindPayout {
		if summary.PayoutCents, err = addCents(summary.PayoutCents, sign*journal.AmountCents); err != nil {
			return err
		}
	}
	for _, entry := range journal.Entries {
		value := entry.AmountCents
		if entry.Direction == Credit {
			value = -value
		}
		if entry.Account == AccountFunds {
			if summary.PlatformFundsCents, err = addCents(summary.PlatformFundsCents, value); err != nil {
				return err
			}
		} else if entry.Account == AccountPayable {
			if summary.WorkerPayableCents, err = addCents(summary.WorkerPayableCents, -value); err != nil {
				return err
			}
		}
	}
	return nil
}
