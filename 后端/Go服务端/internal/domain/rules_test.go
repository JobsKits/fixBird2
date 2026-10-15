package domain

import (
	"math"
	"testing"
)

func TestSplitAmountConservesEveryCent(t *testing.T) {
	for amount := int64(1); amount <= 20_000; amount++ {
		worker, fee, err := SplitDemoAmount(amount)
		if err != nil || worker+fee != amount || worker != (amount*85+50)/100 {
			t.Fatalf("incorrect split for %d", amount)
		}
	}
	worker, fee, err := SplitDemoAmount(10)
	if err != nil || worker != 9 || fee != 1 {
		t.Fatal("10 cents must be worker 9 + fee 1")
	}
	for _, amount := range []int64{0, -1, MaxQuoteCents + 1, math.MaxInt64} {
		if _, _, err := SplitDemoAmount(amount); err == nil {
			t.Fatalf("accepted amount %d", amount)
		}
	}
	if _, _, err := SplitDemoAmount(MaxQuoteCents); err != nil {
		t.Fatal(err)
	}
	if _, err := AddCents(math.MaxInt64, 1); err == nil {
		t.Fatal("overflow was accepted")
	}
	if _, err := AddCents(0, -1); err == nil {
		t.Fatal("negative total was accepted")
	}
}
