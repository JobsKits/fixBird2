//go:build darwin || linux

// Created by Jobs on 2026年11月3日，星期二.
package workbench

import (
	"os"
	"syscall"
)

// 持有内核排他锁，进程异常退出时由系统释放。
func lockWriterGuard(file *os.File) error {
	return syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
}

// 释放仍在当前进程持有的文件锁。
func unlockWriterGuard(file *os.File) error {
	return syscall.Flock(int(file.Fd()), syscall.LOCK_UN)
}

// 只有进程明确不存在时才允许回收旧写入标记。
func writerProcessDead(pid int) (bool, error) {
	err := syscall.Kill(pid, 0)
	switch err {
	case nil, syscall.EPERM:
		return false, nil
	case syscall.ESRCH:
		return true, nil
	default:
		return false, err
	}
}
