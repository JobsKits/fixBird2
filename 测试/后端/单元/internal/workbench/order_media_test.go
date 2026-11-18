package workbench

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestInitialOrderMediaHTTPAboveStandardBodyLimit(t *testing.T) {
	s, _ := testService(t)
	video, _ := base64.StdEncoding.DecodeString(orderVideoFixture)
	padding := make([]byte, 10*1024*1024)
	binary.BigEndian.PutUint32(padding[:4], uint32(len(padding)))
	copy(padding[4:8], "free")
	video = append(video, padding...)
	input := CreateOrderInput{Type: "mail", Customer: "大设备视频", CustomerID: "customer", CompanyID: "company-a", Device: "设备", Description: "独立HTTP夹具", Files: []OrderMediaInput{{Name: "设备.mp4", MIME: "video/mp4", DataBase64: base64.StdEncoding.EncodeToString(video)}}}
	raw, _ := json.Marshal(input)
	if len(raw) <= 12*1024*1024 {
		t.Fatal("fixture must exceed the ordinary request limit")
	}
	token, _, _ := s.login("admin", "1234", "large-device-video")
	request := httptest.NewRequest(http.MethodPost, "/api/v38/orders", bytes.NewReader(raw))
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Idempotency-Key", "large-device-video")
	response := httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(response, request)
	if response.Code != 201 {
		t.Fatal("initial media creation must use its bounded larger body limit", response.Code, response.Body.String())
	}
	var order Order
	_ = json.Unmarshal(response.Body.Bytes(), &order)
	if len(order.Evidence) != 1 || order.Evidence[0].Data != "" {
		t.Fatal("initial media response leaked bytes or lost its file")
	}
}

func mediaOrderWrite(s *Service, actor Actor, input CreateOrderInput, key string) (Order, error) {
	raw, _ := json.Marshal(input)
	body, _, err := s.transact(actor, "POST /api/v38/orders", key, raw, 201, func(state *State) (any, error) {
		return s.createOrder(state, actor, input)
	})
	var order Order
	if err == nil {
		err = json.Unmarshal(body, &order)
	}
	return order, err
}

func TestInitialOrderMediaAtomicityPermissionsAndReplay(t *testing.T) {
	s, persistence := testService(t)
	image := strings.TrimPrefix(syntheticSignature(), "data:image/png;base64,")
	input := CreateOrderInput{Type: "mail", Customer: "设备附件客户", CustomerID: "customer", CompanyID: "company-a", Device: "设备", Description: "图片视频原子提交", Files: []OrderMediaInput{{Name: "设备.png", MIME: "image/png", DataBase64: image}, {Name: "设备.mp4", MIME: "video/mp4", DataBase64: orderVideoFixture}}}
	admin := testActor(s, "admin")
	order, err := mediaOrderWrite(s, admin, input, "media-create")
	if err != nil || len(order.Evidence) != 2 || order.Evidence[0].Data != "" || order.Evidence[1].Data != "" {
		t.Fatal("order projection must have metadata without media bytes", err)
	}
	actual := testOrder(t, s, order.ID)
	if actual.Evidence[0].Data != image || actual.Evidence[1].Data != orderVideoFixture || actual.Evidence[0].SHA256 == "" {
		t.Fatal("private image/video bytes were not persisted together")
	}
	count := len(s.state.Orders)
	replayed, err := mediaOrderWrite(s, admin, input, "media-create")
	if err != nil || replayed.ID != order.ID || len(s.state.Orders) != count {
		t.Fatal("same intent created duplicate media order", err)
	}
	token, _, _ := s.login("customer", "Demo-Repair-2026!", "media-http")
	request := httptest.NewRequest(http.MethodGet, "/api/v38/orders/"+order.ID+"/evidence/"+order.Evidence[0].ID, nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(response, request)
	bytes, _ := base64.StdEncoding.DecodeString(image)
	if response.Code != 200 || response.Body.Len() != len(bytes) || response.Header().Get("Content-Type") != "image/png" {
		t.Fatal("owner could not retrieve original device image")
	}
	other, _, _ := s.login("customer-b", "Demo-Repair-2026!", "media-other")
	request = httptest.NewRequest(http.MethodGet, request.URL.String(), nil)
	request.Header.Set("Authorization", "Bearer "+other)
	response = httptest.NewRecorder()
	s.Handler(t.TempDir()).ServeHTTP(response, request)
	if response.Code != 404 {
		t.Fatal("foreign company could retrieve device media")
	}
	restarted, err := New(persistence)
	if err != nil || testOrder(t, restarted, order.ID).Evidence[1].Data != orderVideoFixture {
		t.Fatal("device media did not survive restart", err)
	}
	input.Files[1].DataBase64 = base64.StdEncoding.EncodeToString([]byte("0000ftypisom0000"))
	if _, err := mediaOrderWrite(s, admin, input, "bad-video"); err == nil || len(s.state.Orders) != count {
		t.Fatal("incomplete video left a partially created order")
	}
	input.Files = []OrderMediaInput{{Name: "伪造.png", MIME: "image/png", DataBase64: base64.StdEncoding.EncodeToString([]byte("not an image"))}}
	if _, err := mediaOrderWrite(s, admin, input, "bad-image"); err == nil || len(s.state.Orders) != count {
		t.Fatal("false image left a partially created order")
	}
	input.Files = []OrderMediaInput{{Name: "../路径.png", MIME: "image/png", DataBase64: image}}
	if _, err := mediaOrderWrite(s, admin, input, "bad-name"); err == nil {
		t.Fatal("path-like attachment name accepted")
	}
	input.Files = make([]OrderMediaInput, 9)
	if _, err := mediaOrderWrite(s, admin, input, "too-many"); err == nil {
		t.Fatal("attachment count limit escaped")
	}
	input.Files = []OrderMediaInput{{Name: "大图.png", MIME: "image/png", DataBase64: strings.Repeat("A", base64.StdEncoding.EncodedLen(journalImageMax)+4)}}
	if _, err := mediaOrderWrite(s, admin, input, "too-large"); err == nil {
		t.Fatal("image limit escaped")
	}
}

// Synthetic 32×32 green H.264 clip generated locally with FFmpeg.
const orderVideoFixture = "AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAANcbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAAHgAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAod0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAAHgAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAACAAAAAgAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAB4AAAEAAABAAAAAAH/bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAAAyAAAABgBVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAABqm1pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAWpzdGJsAAAAvnN0c2QAAAAAAAAAAQAAAK5hdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAACAAIABIAAAASAAAAAAAAAABFExhdmM2My4xLjEwMiBsaWJ4MjY0AAAAAAAAAAAAAAAAGP//AAAANGF2Y0MBZAAK/+EAF2dkAAqs2UlsBEAAAAMAQAAADIPEiWWAAQAGaOvjyyLA/fj4AAAAABBwYXNwAAAAAQAAAAEAAAAUYnRydAAAAAAAAMF9AAAAAAAAABhzdHRzAAAAAAAAAAEAAAADAAACAAAAABRzdHNzAAAAAAAAAAEAAAABAAAAKGN0dHMAAAAAAAAAAwAAAAEAAAQAAAAAAQAABgAAAAABAAACAAAAABxzdHNjAAAAAAAAAAEAAAABAAAAAwAAAAEAAAAgc3RzegAAAAAAAAAAAAAAAwAAAs8AAAAMAAAADAAAABRzdGNvAAAAAAAAAAEAAAOMAAAAYXVkdGEAAABZbWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAAAsaWxzdAAAACSpdG9vAAAAHGRhdGEAAAABAAAAAExhdmY2My4xLjEwMgAAAAhmcmVlAAAC721kYXQAAAKuBgX//6rcRem95tlIt5Ys2CDZI+7veDI2NCAtIGNvcmUgMTY1IHIzMjIyIGIzNTYwNWEgLSBILjI2NC9NUEVHLTQgQVZDIGNvZGVjIC0gQ29weWxlZnQgMjAwMy0yMDI1IC0gaHR0cDovL3d3dy52aWRlb2xhbi5vcmcveDI2NC5odG1sIC0gb3B0aW9uczogY2FiYWM9MSByZWY9MyBkZWJsb2NrPTE6MDowIGFuYWx5c2U9MHgzOjB4MTEzIG1lPWhleCBzdWJtZT03IHBzeT0xIHBzeV9yZD0xLjAwOjAuMDAgbWl4ZWRfcmVmPTEgbWVfcmFuZ2U9MTYgY2hyb21hX21lPTEgdHJlbGxpcz0xIDh4OGRjdD0xIGNxbT0wIGRlYWR6b25lPTIxLDExIGZhc3RfcHNraXA9MSBjaHJvbWFfcXBfb2Zmc2V0PS0yIHRocmVhZHM9MSBsb29rYWhlYWRfdGhyZWFkcz0xIHNsaWNlZF90aHJlYWRzPTAgbnI9MCBkZWNpbWF0ZT0xIGludGVybGFjZWQ9MCBibHVyYXlfY29tcGF0PTAgY29uc3RyYWluZWRfaW50cmE9MCBiZnJhbWVzPTMgYl9weXJhbWlkPTIgYl9hZGFwdD0xIGJfYmlhcz0wIGRpcmVjdD0xIHdlaWdodGI9MSBvcGVuX2dvcD0wIHdlaWdodHA9MiBrZXlpbnQ9MjUwIGtleWludF9taW49MjUgc2NlbmVjdXQ9NDAgaW50cmFfcmVmcmVzaD0wIHJjX2xvb2thaGVhZD00MCByYz1jcmYgbWJ0cmVlPTEgY3JmPTIzLjAgcWNvbXA9MC42MCBxcG1pbj0wIHFwbWF4PTY5IHFwc3RlcD00IGlwX3JhdGlvPTEuNDAgYXE9MToxLjAwAIAAAAAZZYiEADP//t8y+BTNxYnOukxW1fMJalJI/wAAAAhBmiJsQr/+VgAAAAgBnkF5Cv9awQ=="
