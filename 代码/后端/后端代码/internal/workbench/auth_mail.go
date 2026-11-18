// Created by Jobs on 2026年11月18日，星期三.
package workbench

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/mail"
	"net/smtp"
	"os"
	"strings"
	"time"
)

func deliverAuthEmail(ctx context.Context, to, purpose, code string) error {
	host, from := strings.TrimSpace(os.Getenv("WB_SMTP_HOST")), os.Getenv("WB_SMTP_FROM")
	port, mode := os.Getenv("WB_SMTP_PORT"), os.Getenv("WB_SMTP_TLS_MODE")
	if port == "" {
		port = "587"
	}
	if mode == "" {
		mode = "starttls"
	}
	sender, err := mail.ParseAddress(from)
	if host == "" || err != nil || strings.ContainsAny(from, "\r\n") || (mode != "starttls" && mode != "implicit") {
		return fmt.Errorf("SMTP configuration unavailable")
	}
	address := net.JoinHostPort(host, port)
	dialer := &net.Dialer{Timeout: 6 * time.Second}
	var conn net.Conn
	if mode == "implicit" {
		conn, err = (&tls.Dialer{NetDialer: dialer, Config: &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}}).DialContext(ctx, "tcp", address)
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", address)
	}
	if err != nil {
		return err
	}
	defer conn.Close()
	deadline := time.Now().Add(10 * time.Second)
	if requestDeadline, ok := ctx.Deadline(); ok && requestDeadline.Before(deadline) {
		deadline = requestDeadline
	}
	_ = conn.SetDeadline(deadline)
	client, err := smtp.NewClient(conn, host)
	if err != nil {
		return err
	}
	defer client.Close()
	if mode != "implicit" {
		if ok, _ := client.Extension("STARTTLS"); !ok {
			return fmt.Errorf("SMTP requires TLS")
		}
		if err = client.StartTLS(&tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}); err != nil {
			return err
		}
	}
	if username := os.Getenv("WB_SMTP_USERNAME"); username != "" {
		if err = client.Auth(smtp.PlainAuth("", username, os.Getenv("WB_SMTP_PASSWORD"), host)); err != nil {
			return err
		}
	}
	if err = client.Mail(sender.Address); err != nil {
		return err
	}
	if err = client.Rcpt(to); err != nil {
		return err
	}
	body, err := client.Data()
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(body, "From: %s\r\nTo: %s\r\nSubject: Repair workbench verification code\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nYour %s verification code is %s. It expires in 10 minutes.\r\n", sender.Address, to, purpose, code)
	if err != nil {
		_ = body.Close()
		return err
	}
	if err = body.Close(); err != nil {
		return err
	}
	return client.Quit()
}
