package main

import (
	"flag"
	"os"
	"strings"
	"testing"
)

func TestClearStorageRejectsMissingConfirmationAndMixedOperations(t *testing.T) {
	for _, args := range [][]string{
		{"-clear-storage"},
		{"-confirm-clear-storage"},
		{"-clear-storage", "-confirm-clear-storage", "-backup", "unused.wbbak"},
		{"-clear-storage", "-confirm-clear-storage", "-restore", "unused.wbbak"},
		{"-clear-storage", "-confirm-clear-storage", "-restore-target", "unused"},
		{"-clear-storage", "-confirm-clear-storage"},
		{"-clear-storage-backup", "unused.wbbak"},
		{"-clear-storage", "-clear-storage-backup", "unused.wbbak"},
		{"-clear-storage", "-confirm-clear-storage", "-clear-storage-backup", "unused.wbbak", "-backup", "another.wbbak"},
	} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			oldFlags, oldArgs := flag.CommandLine, os.Args
			flag.CommandLine = flag.NewFlagSet("clear-test", flag.ContinueOnError)
			os.Args = append([]string{"clear-test"}, args...)
			defer func() { flag.CommandLine = oldFlags; os.Args = oldArgs }()
			t.Setenv("WB_TIDB_DSN", "")
			if err := run(); err == nil {
				t.Fatal("unsafe clear accepted")
			}
		})
	}
}
