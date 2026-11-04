// Created by Jobs on 2026年11月3日，星期二.
package workbench

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// 持久内核锁串行化旧PID锁的恢复；强制退出后由操作系统释放。
func acquireWriterLock(dir string) (writer, guard *os.File, err error) {
	guardPath := filepath.Join(dir, ".writer.guard")
	if info, statErr := os.Lstat(guardPath); statErr == nil && !info.Mode().IsRegular() {
		return nil, nil, errors.New("数据目录的 .writer.guard 不是普通文件，拒绝跟随或替换")
	} else if statErr != nil && !errors.Is(statErr, os.ErrNotExist) {
		return nil, nil, fmt.Errorf("检查数据目录内核锁失败: %w", statErr)
	}
	guard, err = os.OpenFile(guardPath, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, nil, fmt.Errorf("打开数据目录内核锁失败: %w", err)
	}
	if err = lockWriterGuard(guard); err != nil {
		_ = guard.Close()
		return nil, nil, fmt.Errorf("无法独占数据目录，已有服务占用或系统不支持文件锁: %w", err)
	}
	defer func() {
		if err != nil {
			_ = unlockWriterGuard(guard)
			_ = guard.Close()
			guard = nil
		}
	}()
	lockPath := filepath.Join(dir, "writer.lock")
	writer, err = os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if errors.Is(err, os.ErrExist) {
		if err = recoverAbandonedWriterLock(lockPath); err != nil {
			return nil, guard, err
		}
		writer, err = os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	}
	if err != nil {
		return nil, guard, fmt.Errorf("创建数据目录 writer.lock 失败: %w", err)
	}
	_, err = fmt.Fprintf(writer, "%d\n", os.Getpid())
	if err == nil {
		err = writer.Sync()
	}
	if err != nil {
		_ = writer.Close()
		_ = os.Remove(lockPath)
		return nil, guard, fmt.Errorf("写入数据目录 writer.lock 失败: %w", err)
	}
	return writer, guard, nil
}

// 只有确认旧PID已不存在且文件未被替换时才回收，未知状态保留原锁。
func recoverAbandonedWriterLock(path string) error {
	content, info, err := readWriterLock(path)
	if err != nil {
		return err
	}
	text := strings.TrimSpace(string(content))
	for _, ch := range text {
		if ch < '0' || ch > '9' {
			return errors.New("writer.lock 的PID无效，无法确认占用者，保留原锁")
		}
	}
	pid, err := strconv.Atoi(text)
	if err != nil || pid <= 0 {
		return errors.New("writer.lock 的PID为空或无效，无法确认占用者，保留原锁")
	}
	dead, err := writerProcessDead(pid)
	if err != nil {
		return fmt.Errorf("无法核实 writer.lock 的PID %d，保留原锁: %w", pid, err)
	}
	if !dead {
		return fmt.Errorf("数据目录被PID %d占用或无法确认已退出，保留 writer.lock；请先停止对应服务", pid)
	}
	current, currentInfo, err := readWriterLock(path)
	if err != nil {
		return err
	}
	if !os.SameFile(info, currentInfo) || string(content) != string(current) {
		return errors.New("writer.lock 在核验期间发生变化，保留当前锁并停止启动")
	}
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("回收已退出PID %d的 writer.lock 失败: %w", pid, err)
	}
	return nil
}

// 限制读取大小并拒绝符号链接，锁文件只允许保存简短PID。
func readWriterLock(path string) ([]byte, os.FileInfo, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return nil, nil, fmt.Errorf("检查 writer.lock 失败: %w", err)
	}
	if !info.Mode().IsRegular() {
		return nil, nil, errors.New("writer.lock 不是普通文件，拒绝跟随或替换")
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, fmt.Errorf("读取 writer.lock 失败: %w", err)
	}
	defer file.Close()
	opened, err := file.Stat()
	if err != nil || !os.SameFile(info, opened) {
		return nil, nil, errors.New("writer.lock 在打开时发生变化，保留当前锁")
	}
	content, err := io.ReadAll(io.LimitReader(file, 65))
	if err != nil || len(content) > 64 {
		return nil, nil, errors.New("writer.lock 无法读取或内容过长，保留原锁")
	}
	return content, info, nil
}
