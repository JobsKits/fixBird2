//
//  WBActionCatalog.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation
import JobsSwiftBlock
import JobsSwiftDSL

enum WBActionCatalog {
    static let titles = [
        "handover_contact": "交接客户经办人", "review_acceptance": "核实线下异议", "intake": "确认受理",
        "receive": "确认公司收件", "assign": "安排 / 改派", "diagnose": "开始检测 / 询价",
        "report": "提交检测报告", "quote": "拟定报价", "approve_quote": "审核并发送报价",
        "sign_quote": "签署报价与维修确认", "start": "确认开始维修", "finish": "提交维修完工",
        "qc": "确认公司质检", "stock_ready": "销售备货 / 出库", "dispatch": "登记实际发货",
        "deliver": "确认客户签收 / 交接", "accept": "签署最终验收", "requirements": "确认资料与开票约定",
        "documents": "制作 / 发送付款资料", "cash": "登记现金收款 / 退款", "verify_cash": "财务核实现金",
        "handover_cash": "确认内部现金交接", "invoice": "登记真实发票", "void_invoice": "红冲 / 作废原票",
        "adjust_receivable": "批准调整应收", "remark": "编辑工单备注", "evidence": "归档业务资料",
        "delete_evidence": "删除本人证据", "issue": "登记异议 / 协商", "resolve_issue": "记录协商处理结果",
        "failure": "批准停止履约", "obligation": "新增内部余项", "resolve_obligation": "办理内部余项",
        "visit": "安排上门行程", "start_visit": "确认实际到场", "outsource": "登记外包 / 后续流向",
        "cost": "登记内部成本", "approve_cost": "审核成本", "commission": "登记提成",
        "settle_commission": "核实提成结算", "complete": "核对并整单完结", "reopen": "批准重开办理",
        "rework": "创建关联返修单"
    ]

    static func title(_ action: String) -> String {
        return titles[action] ?? "办理工单"
    }

    static func amount(_ cents: Int64) -> String {
        return String(format: "%.2f", Double(cents) / 100)
    }

    static var businessCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }

    static func date(_ days: Int = 0, now: Date = Date()) -> String {
        let calendar = businessCalendar
        let result = calendar.date(byAdding: .day, value: days, to: now) ?? now
        return DateFormatter.jobsMake { formatter in
            formatter.byLocale(Locale(identifier: "en_US_POSIX"))
                .byCalendar(calendar)
                .byTimeZone(calendar.timeZone)
                .byDateFormat("yyyy-MM-dd")
        }.string(from: result)
    }

    static func instant() -> String {
        return ISO8601DateFormatter.jobsMake { _ in }.string(from: Date())
    }
}
