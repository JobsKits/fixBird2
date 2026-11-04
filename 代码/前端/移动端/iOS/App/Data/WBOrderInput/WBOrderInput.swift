//
//  WBOrderInput.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBOrderInput {
    var type = "mail"
    var customer = ""
    var customerId = ""
    var companyId = ""
    var project = ""
    var device = ""
    var description = ""
    var remark = ""
    var customerNote = ""

    func byType(_ value: String) -> Self {
        var copy = self
        copy.type = value
        return copy
    }

    func byCustomer(_ value: String) -> Self {
        var copy = self
        copy.customer = value
        return copy
    }

    func byCustomerId(_ value: String) -> Self {
        var copy = self
        copy.customerId = value
        return copy
    }

    func byCompanyId(_ value: String) -> Self {
        var copy = self
        copy.companyId = value
        return copy
    }

    func byProject(_ value: String) -> Self {
        var copy = self
        copy.project = value
        return copy
    }

    func byDevice(_ value: String) -> Self {
        var copy = self
        copy.device = value
        return copy
    }

    func byDescription(_ value: String) -> Self {
        var copy = self
        copy.description = value
        return copy
    }

    func byRemark(_ value: String) -> Self {
        var copy = self
        copy.remark = value
        return copy
    }

    func byCustomerNote(_ value: String) -> Self {
        var copy = self
        copy.customerNote = value
        return copy
    }

    var payload: [String: Any] {
        [
            "type": type, "customer": customer, "customerId": customerId, "companyId": companyId, "project": project,
            "device": device, "description": description, "remark": remark, "customerNote": customerNote,
        ]
    }
}
