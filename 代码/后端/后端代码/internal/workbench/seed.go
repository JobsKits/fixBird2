package workbench

import (
	"bytes"
	"encoding/base64"
	"image"
	"image/color"
	"image/png"
	"time"
)

func seedState() (State, error) {
	// Security history is an explicit list so recovery can validate its source.
	now := time.Now().UTC()
	state := State{Schema: 38, Audit: []AuditEvent{}, Accounts: []Account{}, Orders: []Order{}, Loans: []Loan{}, Purchases: []Purchase{}, Requests: map[string]CachedRequest{}, Settings: Settings{CompanyAddress: "合成演示地址：上海市示范路 38 号维修服务中心", CompanyReceiver: "演示收件人", CompanyPhone: "000-00000000", ReminderHours: 24, RemarkLimit: 2000, Demo: true}, Parts: []Part{{ID: "part-board", Name: "工业控制主板", SKU: "PCB-38", Available: 28, Quarantine: 1}, {ID: "part-sensor", Name: "温度传感器", SKU: "SNS-24", Available: 64, Quarantine: 0}, {ID: "part-power", Name: "24V 电源模块", SKU: "PWR-24", Available: 16, Quarantine: 0}}}
	names := map[string]string{"admin": "公司负责人", "dispatcher": "客服调度", "engineer": "自有工程师", "outsource": "一手外包", "warehouse": "仓库管理员", "qc": "质检员", "finance": "财务人员", "customer": "海棠物业联系人", "customer-peer": "海棠物业接替联系人", "customer-b": "青禾物业联系人", "supplier": "配件供应商"}
	for _, username := range []string{"admin", "dispatcher", "engineer", "outsource", "warehouse", "qc", "finance", "customer", "customer-peer", "customer-b", "supplier"} {
		role := username
		company := "internal"
		if username == "customer" {
			company = "company-a"
		}
		if username == "customer-peer" {
			role = "customer"
			company = "company-a"
		}
		if username == "customer-b" {
			role = "customer"
			company = "company-b"
		}
		if username == "supplier" {
			company = "supplier-demo"
		}
		salt := randomID("")
		hash, err := passwordHash("Demo-Repair-2026!", salt)
		if err != nil {
			return State{}, err
		}
		state.Accounts = append(state.Accounts, Account{Actor: Actor{ID: username, Username: username, Name: names[username], Role: role, CompanyID: company, Status: "active", AuthVersion: 1}, Salt: salt, Hash: hash})
	}
	add := func(id, number, kind, project, device, description, status string) *Order {
		o := newOrder(id, CreateOrderInput{Type: kind, Customer: "海棠物业管理有限公司（合成）", CustomerID: "customer", CompanyID: "company-a", Project: project, Device: device, Description: description}, now.Add(-48*time.Hour))
		o.Number = number
		o.Status = status
		o.OwnerID = "dispatcher"
		o.AssigneeID = "engineer"
		o.Remark = "合成样例；内部交接说明仅公司授权人员可见"
		o.CustomerNote = "本单为开发演示样例，请勿提交真实资料。"
		o.Events = []Event{{ID: randomID("ev_"), Type: "seed", Title: "载入合成业务样例", Note: "样例事实和签名均为程序生成，不代表真实履约", ActorID: "system", ActorName: "演示初始化", At: nowString(now.Add(-48 * time.Hour)), Version: 1}}
		state.Orders = append(state.Orders, o)
		return &state.Orders[len(state.Orders)-1]
	}
	add("wo_intake", "ZM20261013-0001", "onsite", "松风花园 · 机房", "变频水泵控制柜", "频繁跳闸，预约现场检测", "pending_intake")
	o := add("wo_quote", "ZM20261013-0002", "mail", "海棠中心 · 中控", "工业控制主板", "上电无响应，需要检测与维修报价", "pending_customer_confirmation")
	o.Quote = Quote{Version: 1, AmountCents: 128000, Description: "更换供电模块，板级维修与老化测试；含税总价1280元", WarrantyMonths: 3, PaymentTerms: "credit", ValidUntil: nowString(now.Add(72 * time.Hour)), Approved: true, AutoAccept: true}
	o.ReceivableCents = 128000
	o = add("wo_repair", "ZM20261013-0003", "onsite", "松风花园 · 地库", "排污泵控制系统", "已确认维修，现场更换故障传感器", "repairing")
	o.Quote = seedSignedQuote(now, 68000, "现场维修与调试", false)
	o.ReceivableCents = 68000
	o.Visits = []Visit{{ID: "visit_seed", PlannedAt: nowString(now.Add(3 * time.Hour)), FeeMemo: "内部差旅预计80元；不得向客户展示", Note: "入场需联系物业"}}
	o = add("wo_sale", "ZM20261013-0004", "sale", "海棠中心 · 配件补货", "24V 电源模块 × 2", "销售询价，按批准账期备货", "diagnosis_quotation")
	o.Quote = Quote{Version: 1, AmountCents: 96000, Description: "24V电源模块2件，含税价960元，物业账期30日", WarrantyMonths: 3, PaymentTerms: "credit", ValidUntil: nowString(now.Add(72 * time.Hour)), AutoAccept: true}
	o.ReceivableCents = 96000
	o = add("wo_settling", "ZM20261013-0005", "mail", "海棠中心 · 消防主机", "消防报警控制主机", "维修已验收，付款资料及尾款待办", "settling")
	o.Quote = seedSignedQuote(now, 300000, "维修与测试", true)
	o.ReceivableCents = 300000
	o.Outcome = "accepted"
	o.AcceptedAt = nowString(now.Add(-24 * time.Hour))
	o.Warranty = Warranty{StartsAt: o.AcceptedAt, EndsAt: nowString(now.AddDate(0, 3, 0))}
	o.Documents = Documents{Requirement: "required", Reason: "客户付款报销约定", Version: 1, Prepared: true, Files: []string{"file_report"}}
	o.Evidence = []Evidence{{ID: "file_report", Name: "合成维修报告.txt", Kind: "text", Text: "合成样例维修报告，无真实客户资料", MIME: "text/plain", UploaderID: "dispatcher", CreatedAt: nowString(now), Stage: "settling", Public: true}}
	o.InvoiceRequirement = "required"
	o.InvoiceReason = "客户需含税发票"
	o.InvoiceDueCents = 300000
	o.Cash = []Cash{{ID: "cash_seed", AmountCents: 100000, Kind: "receipt", Purpose: "合成预付款", Receipt: "合成收据DEMO-001", Collector: "dispatcher", OccurredAt: nowString(now.Add(-24 * time.Hour)), Verified: true, HandedOver: true, VerifiedBy: "finance"}}
	o = add("wo_ready", "ZM20261013-0006", "mail", "松风花园 · 控制室", "门禁控制板", "资料票款均齐，等待负责人最终完结", "pending_completion")
	o.Quote = seedSignedQuote(now, 50000, "板级维修", true)
	o.ReceivableCents = 50000
	o.Outcome = "accepted"
	o.AcceptedAt = nowString(now.Add(-48 * time.Hour))
	o.Warranty = Warranty{StartsAt: o.AcceptedAt, EndsAt: nowString(now.AddDate(0, 3, 0))}
	o.Documents.Requirement = "none"
	o.Documents.Reason = "合成客户无需报销资料"
	o.InvoiceRequirement = "none"
	o.InvoiceReason = "合成客户明确无需开票"
	o.Cash = []Cash{{ID: "cash_ready", AmountCents: 50000, Kind: "receipt", Purpose: "合成全款", Receipt: "合成收据DEMO-002", Collector: "finance", OccurredAt: nowString(now.Add(-24 * time.Hour)), Verified: true, HandedOver: true, VerifiedBy: "finance"}}
	o = add("wo_failure", "ZM20261013-0007", "mail", "海棠中心 · 旧设备", "停产控制模块", "技术不能修，批准停止后仍待退件", "settling")
	o.Outcome = "failed"
	o.FailureReason = "unrepairable"
	o.Documents.Requirement = "none"
	o.Documents.Reason = "合成失败处理约定无需资料"
	o.InvoiceRequirement = "none"
	o.InvoiceReason = "无应收无需票据"
	o.Obligations = []Task{{ID: "task_return", Title: "核实设备退件及客户实收", OwnerID: "warehouse", DueAt: nowString(now.Add(48 * time.Hour))}}
	o = add("wo_company_b", "ZM20261013-0008", "sale", "青禾物业 · 独立企业", "温度传感器", "第二企业合成样例，用于验证访问隔离", "pending_intake")
	o.Customer = "青禾物业（合成）"
	o.CustomerID = "customer-b"
	o.CompanyID = "company-b"
	state.Purchases = []Purchase{{ID: "purchase_seed", Version: 1, Supplier: "supplier", PartID: "part-board", Quantity: 10, Received: 4, UnitCents: 32000, Note: "合成采购批准，支持分批收货"}}
	return state, nil
}

func seedSignedQuote(now time.Time, amount int64, description string, auto bool) Quote {
	return Quote{Version: 1, AmountCents: amount, Description: description, WarrantyMonths: 3, PaymentTerms: "credit", ValidUntil: nowString(now.Add(-time.Hour)), Approved: true, Signed: true, Signature: syntheticSignature(), Signer: "合成客户签名样例", SignedAt: nowString(now.Add(-48 * time.Hour)), AutoAccept: auto}
}

func syntheticSignature() string {
	img := image.NewRGBA(image.Rect(0, 0, 160, 64))
	for y := 8; y < 56; y++ {
		x := 20 + (y*2)%120
		for w := 0; w < 3; w++ {
			img.Set(x+w, y, color.RGBA{R: 25, G: 40, B: 65, A: 255})
		}
	}
	var buffer bytes.Buffer
	_ = png.Encode(&buffer, img)
	return "data:image/png;base64," + base64.StdEncoding.EncodeToString(buffer.Bytes())
}
