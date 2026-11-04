// Created by Jobs on 2026年11月3日，星期二.
package workbench

import (
	"errors"
	"fmt"
	"os"
	"runtime"
	"syscall"
	"unsafe"
)

var (
	writerKernel32     = syscall.NewLazyDLL("kernel32.dll")
	writerLockFileEx   = writerKernel32.NewProc("LockFileEx")
	writerUnlockFileEx = writerKernel32.NewProc("UnlockFileEx")
)

// 用非阻塞字节锁串行化锁文件的检查与接管，进程退出后由系统释放。
func lockWriterGuard(file *os.File) error {
	if file == nil {
		return os.ErrInvalid
	}
	if err := writerLockFileEx.Find(); err != nil {
		return err
	}
	const lockFailImmediately = 0x00000001
	const lockExclusive = 0x00000002
	var overlapped syscall.Overlapped
	result, _, err := writerLockFileEx.Call(file.Fd(), lockFailImmediately|lockExclusive, 0, 1, 0, uintptr(unsafe.Pointer(&overlapped)))
	runtime.KeepAlive(file)
	if result != 0 {
		return nil
	}
	if err == syscall.Errno(0) {
		return errors.New("Windows LockFileEx失败，未返回错误码")
	}
	return err
}

// 只释放本句柄持有的首字节锁，不影响其它文件或进程。
func unlockWriterGuard(file *os.File) error {
	if file == nil {
		return os.ErrInvalid
	}
	if err := writerUnlockFileEx.Find(); err != nil {
		return err
	}
	var overlapped syscall.Overlapped
	result, _, err := writerUnlockFileEx.Call(file.Fd(), 0, 1, 0, uintptr(unsafe.Pointer(&overlapped)))
	runtime.KeepAlive(file)
	if result != 0 {
		return nil
	}
	if err == syscall.Errno(0) {
		return errors.New("Windows UnlockFileEx失败，未返回错误码")
	}
	return err
}

// 仅在进程不存在或退出事件已触发时认定死亡；权限与未知状态均拒绝接管。
func writerProcessDead(pid int) (bool, error) {
	if pid <= 0 || uint64(pid) > uint64(^uint32(0)) {
		return false, fmt.Errorf("无效的Windows写入进程PID: %d", pid)
	}
	handle, err := syscall.OpenProcess(syscall.SYNCHRONIZE, false, uint32(pid))
	if err != nil {
		const errorInvalidParameter = syscall.Errno(87)
		if errors.Is(err, errorInvalidParameter) {
			return true, nil
		}
		return false, err
	}
	defer syscall.CloseHandle(handle)
	state, err := syscall.WaitForSingleObject(handle, 0)
	if err != nil {
		return false, err
	}
	switch state {
	case syscall.WAIT_OBJECT_0:
		return true, nil
	case syscall.WAIT_TIMEOUT:
		return false, nil
	default:
		return false, fmt.Errorf("无法确认Windows写入进程状态: %d", state)
	}
}
