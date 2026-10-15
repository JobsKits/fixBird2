package config

import "testing"

func TestDemoBindingsRequireExplicitNetworkPermission(t *testing.T) {
	for _, address := range []string{"127.0.0.1:8080", "[::1]:8080", "localhost:8080"} {
		if err := (Config{Address: address, DemoMode: true}).Validate(); err != nil {
			t.Fatal(address, err)
		}
	}
	for _, address := range []string{":8080", "0.0.0.0:8080", "[::]:8080", "192.0.2.10:8080", "example.com:8080"} {
		if (Config{Address: address, DemoMode: true}).Validate() == nil {
			t.Fatal("implicit network binding", address)
		}
		if err := (Config{Address: address, DemoMode: true, AllowDemoNetwork: true}).Validate(); err != nil {
			t.Fatal(address, err)
		}
	}
	for _, address := range []string{"127.0.0.1:0", "127.0.0.1:65536", "8080", "127.0.0.1:http"} {
		if (Config{Address: address, DemoMode: true, AllowDemoNetwork: true}).Validate() == nil {
			t.Fatal("invalid address accepted", address)
		}
	}
	if (Config{Address: "127.0.0.1:8080", DemoMode: false, AllowDemoNetwork: true}).Validate() == nil {
		t.Fatal("production mode enabled")
	}
}
