// Created by Jobs on 2026年11月3日，星期二.
package workbench

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

// The child uses the real persistence constructor so process death exercises the kernel guard.
func TestWriterLockSubprocess(t *testing.T) {
	mode := os.Getenv("WB_TEST_WRITER_LOCK_CHILD")
	if mode == "" {
		return
	}
	input := bufio.NewScanner(os.Stdin)
	if mode == "barrier" {
		fmt.Fprintln(os.Stdout, "writer-ready")
		if !input.Scan() || input.Text() != "start" {
			os.Exit(19)
		}
	}
	p, err := NewFilePersistence(os.Getenv("WB_TEST_WRITER_LOCK_DIR"), os.Getenv("WB_TEST_WRITER_LOCK_KEY"))
	if err != nil {
		fmt.Fprintln(os.Stdout, "writer-rejected")
		fmt.Fprintln(os.Stderr, err)
		os.Exit(17)
	}
	fmt.Fprintln(os.Stdout, "writer-acquired")
	input.Scan()
	if err := p.Close(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(18)
	}
	os.Exit(0)
}

type writerLockChild struct {
	command *exec.Cmd
	input   io.WriteCloser
	lines   chan string
	done    chan struct{}
	err     error
	stderr  bytes.Buffer
}

func startWriterLockChild(t *testing.T, dir, key, mode string) *writerLockChild {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	child := &writerLockChild{lines: make(chan string, 4), done: make(chan struct{})}
	child.command = exec.CommandContext(ctx, os.Args[0], "-test.run=^TestWriterLockSubprocess$")
	child.command.Env = append(os.Environ(),
		"WB_TEST_WRITER_LOCK_CHILD="+mode,
		"WB_TEST_WRITER_LOCK_DIR="+dir,
		"WB_TEST_WRITER_LOCK_KEY="+key,
	)
	child.command.Stderr = &child.stderr
	var err error
	child.input, err = child.command.StdinPipe()
	if err != nil {
		cancel()
		t.Fatal(err)
	}
	stdout, stdoutWriter, err := os.Pipe()
	if err != nil {
		child.input.Close()
		cancel()
		t.Fatal(err)
	}
	child.command.Stdout = stdoutWriter
	if err := child.command.Start(); err != nil {
		stdout.Close()
		stdoutWriter.Close()
		child.input.Close()
		cancel()
		t.Fatal(err)
	}
	stdoutWriter.Close()
	go func() {
		defer stdout.Close()
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			child.lines <- scanner.Text()
		}
		close(child.lines)
	}()
	go func() {
		child.err = child.command.Wait()
		close(child.done)
	}()
	t.Cleanup(func() {
		child.input.Close()
		select {
		case <-child.done:
		default:
			child.command.Process.Kill()
			select {
			case <-child.done:
			case <-time.After(5 * time.Second):
				t.Error("writer fixture did not exit after being killed")
			}
		}
		cancel()
	})
	return child
}

func (child *writerLockChild) line(t *testing.T) string {
	t.Helper()
	select {
	case line, ok := <-child.lines:
		if !ok {
			t.Fatal("writer fixture ended before returning its lock status")
		}
		return line
	case <-time.After(5 * time.Second):
		t.Fatal("writer fixture did not return its lock status")
		return ""
	}
}

func (child *writerLockChild) wait(t *testing.T, wantCode int) {
	t.Helper()
	select {
	case <-child.done:
	case <-time.After(5 * time.Second):
		t.Fatal("writer fixture did not exit")
	}
	gotCode := child.command.ProcessState.ExitCode()
	if gotCode != wantCode {
		t.Fatalf("writer fixture exit %d, want %d: %v; %s", gotCode, wantCode, child.err, child.stderr.String())
	}
}

func (child *writerLockChild) kill(t *testing.T) {
	t.Helper()
	if err := child.command.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	select {
	case <-child.done:
	case <-time.After(5 * time.Second):
		t.Fatal("killed writer did not exit")
	}
	if child.err == nil {
		t.Fatal("writer fixture exited normally instead of being killed")
	}
}

func newWriterLockFixture(t *testing.T) (string, string) {
	t.Helper()
	root := t.TempDir()
	dir, key := filepath.Join(root, "data"), filepath.Join(root, "keys", "storage.key")
	p, err := NewFilePersistence(dir, key)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Close(); err != nil {
		t.Fatal(err)
	}
	return dir, key
}

func TestWriterLockCloseReopensAndKeepsGuard(t *testing.T) {
	dir, key := newWriterLockFixture(t)
	if _, err := os.Stat(filepath.Join(dir, ".writer.guard")); err != nil {
		t.Fatalf("persistent guard missing after close: %v", err)
	}
	p, err := NewFilePersistence(dir, key)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Close(); err != nil {
		t.Fatal(err)
	}
	if err := p.Close(); err != nil {
		t.Fatalf("second close: %v", err)
	}
}

func TestWriterLockRecoversAfterKilledProcess(t *testing.T) {
	dir, key := newWriterLockFixture(t)
	child := startWriterLockChild(t, dir, key, "hold")
	if got := child.line(t); got != "writer-acquired" {
		t.Fatalf("child lock status: %s", got)
	}
	lockPath := filepath.Join(dir, "writer.lock")
	wantPID := []byte(strconv.Itoa(child.command.Process.Pid) + "\n")
	before, err := os.ReadFile(lockPath)
	if err != nil || !bytes.Equal(before, wantPID) {
		t.Fatalf("real child PID not written: %q, %v", before, err)
	}
	if other, err := NewFilePersistence(dir, key); err == nil {
		other.Close()
		t.Fatal("second process accepted while child holds the guard")
	}
	child.kill(t)
	stale, err := os.ReadFile(lockPath)
	if err != nil || !bytes.Equal(stale, wantPID) {
		t.Fatalf("abnormal exit did not leave the legacy PID record: %q, %v", stale, err)
	}
	p, err := NewFilePersistence(dir, key)
	if err != nil {
		t.Fatalf("kernel guard was not released or stale PID was not recovered: %v", err)
	}
	defer p.Close()
	if other, err := NewFilePersistence(dir, key); err == nil {
		other.Close()
		t.Fatal("recovered writer allowed a concurrent owner")
	}
}

func TestWriterLockRejectsLiveLegacyPIDWithoutChangingRecord(t *testing.T) {
	dir, key := newWriterLockFixture(t)
	lockPath := filepath.Join(dir, "writer.lock")
	original := []byte(strconv.Itoa(os.Getpid()) + "\n")
	if err := os.WriteFile(lockPath, original, 0600); err != nil {
		t.Fatal(err)
	}
	if other, err := NewFilePersistence(dir, key); err == nil {
		other.Close()
		t.Fatal("live legacy writer was displaced")
	}
	got, err := os.ReadFile(lockPath)
	if err != nil || !bytes.Equal(got, original) {
		t.Fatalf("live legacy PID record changed: %q, %v", got, err)
	}
}

func TestWriterLockRecoversDeadLegacyPID(t *testing.T) {
	dir, key := newWriterLockFixture(t)
	child := startWriterLockChild(t, dir, key, "hold")
	if got := child.line(t); got != "writer-acquired" {
		t.Fatalf("child lock status: %s", got)
	}
	pid := child.command.Process.Pid
	if err := child.input.Close(); err != nil {
		t.Fatal(err)
	}
	child.wait(t, 0)
	if err := os.WriteFile(filepath.Join(dir, "writer.lock"), []byte(strconv.Itoa(pid)+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	p, err := NewFilePersistence(dir, key)
	if err != nil {
		t.Fatalf("confirmed dead legacy PID was not recovered: %v", err)
	}
	defer p.Close()
}

func TestWriterLockPreservesEmptyAndMalformedLegacyRecords(t *testing.T) {
	for _, tc := range []struct {
		name, value string
	}{
		{"empty", ""},
		{"zero", "0\n"},
		{"negative", "-1\n"},
		{"text", "unknown-owner\n"},
		{"multiple-pids", "12\n34\n"},
		{"overflow", "999999999999999999999999999999999\n"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir, key := newWriterLockFixture(t)
			lockPath := filepath.Join(dir, "writer.lock")
			original := []byte(tc.value)
			if err := os.WriteFile(lockPath, original, 0600); err != nil {
				t.Fatal(err)
			}
			if other, err := NewFilePersistence(dir, key); err == nil {
				other.Close()
				t.Fatal("unknown legacy owner was treated as dead")
			}
			got, err := os.ReadFile(lockPath)
			if err != nil || !bytes.Equal(got, original) {
				t.Fatalf("unknown legacy record changed: %q, %v", got, err)
			}
		})
	}
}

func TestWriterLockConcurrentProcessesHaveOneOwner(t *testing.T) {
	dir, key := newWriterLockFixture(t)
	previous := startWriterLockChild(t, dir, key, "hold")
	if got := previous.line(t); got != "writer-acquired" {
		t.Fatalf("previous writer lock status: %s", got)
	}
	previous.kill(t)
	children := []*writerLockChild{
		startWriterLockChild(t, dir, key, "barrier"),
		startWriterLockChild(t, dir, key, "barrier"),
	}
	for _, child := range children {
		if got := child.line(t); got != "writer-ready" {
			t.Fatalf("child did not reach barrier: %s", got)
		}
	}
	for _, child := range children {
		if _, err := io.WriteString(child.input, "start\n"); err != nil {
			t.Fatal(err)
		}
	}
	var winner *writerLockChild
	accepted, rejected := 0, 0
	for _, child := range children {
		switch got := child.line(t); got {
		case "writer-acquired":
			accepted++
			winner = child
		case "writer-rejected":
			rejected++
			child.wait(t, 17)
		default:
			t.Fatalf("unexpected writer status: %s", got)
		}
	}
	if accepted != 1 || rejected != 1 {
		t.Fatalf("concurrent owners: accepted=%d rejected=%d", accepted, rejected)
	}
	if err := winner.input.Close(); err != nil {
		t.Fatal(err)
	}
	winner.wait(t, 0)
	p, err := NewFilePersistence(dir, key)
	if err != nil {
		t.Fatalf("released concurrent writer could not be reopened: %v", err)
	}
	defer p.Close()
}
