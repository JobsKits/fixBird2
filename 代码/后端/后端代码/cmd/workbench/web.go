// Created by Jobs on 2026年10月30日，星期五.
package main

import (
	"net/http"
	"os"
	"path/filepath"
)

// 各客户端共享 API，静态目录独立，避免发布源码和运行数据。
func clientHandler(business http.Handler, adminDir, flutterDir, clientDir, contractDir string) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/", business)
	// Only these bundled public resources are exposed; never serve the shared source tree.
	for name, contentType := range map[string]string{
		"NotoSansSC.ttf":            "font/ttf",
		"NotoSansCJKsc-Regular.otf": "font/otf",
		"NotoSerifTibetan.ttf":      "font/ttf",
		"ui-l10n.json":              "application/json; charset=utf-8",
	} {
		mux.HandleFunc("GET /admin-font/"+name, func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", contentType)
			http.ServeFile(w, r, filepath.Join(adminDir, "../../共享组件/Flutter/assets", name))
		})
	}
	for route, dir := range map[string]string{
		"/admin/":          adminDir,
		"/admin-flutter/":  flutterDir,
		"/client-flutter/": clientDir,
		"/admin-contract/": contractDir,
	} {
		files := http.StripPrefix(route, http.FileServer(http.Dir(filepath.Clean(dir))))
		mux.Handle(route, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if route != "/admin-contract/" {
				if _, err := os.Stat(filepath.Join(dir, "index.html")); err != nil {
					http.Error(w, "此客户端尚未构建，请按对应 README 完成 web 构建后重新加载。", http.StatusServiceUnavailable)
					return
				}
			}
			files.ServeHTTP(w, r)
		}))
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Cache-Control", "no-store")
		mux.ServeHTTP(w, r)
	})
}
