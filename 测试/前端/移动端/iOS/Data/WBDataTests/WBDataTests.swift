//
//  WBDataTests.swift
//  RepairWorkbenchTests
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import ImageIO
import UIKit
import XCTest

import JobsSwiftBaseDefines

@testable import RepairWorkbench

@MainActor
final class WBDataTests: XCTestCase {
    func testUnquotedAndNullCollections() throws {
        try WBDataScenarios.unquotedAndNullCollections()
    }

    func testRejectsCriticalMissingFields() throws {
        try WBDataScenarios.rejectsCriticalMissingFields()
    }

    func testLoanConservation() throws {
        try WBDataScenarios.loanConservation()
    }

    func testLogin401DoesNotFallback() throws {
        try WBDataScenarios.login401DoesNotFallback()
    }

    func testProtected401ClearsPrivateData() throws {
        try WBDataScenarios.protected401ClearsPrivateData()
    }

    func testLateLoginCannotReplaceIdentity() throws {
        try WBDataScenarios.lateLoginCannotReplaceIdentity()
    }

    func testLateOldSession401IsIgnored() throws {
        try WBDataScenarios.lateOldSession401IsIgnored()
    }

    func testFallbackAndRecoveryAreIsolated() throws {
        try WBDataScenarios.fallbackAndRecoveryAreIsolated()
    }

    func testEmptyRealListIsNotFailure() throws {
        try WBDataScenarios.emptyRealListIsNotFailure()
    }

    func testActorMismatchIsRejected() throws {
        try WBDataScenarios.actorMismatchIsRejected()
    }

    func testOverlappingRefreshBalancesBusy() throws {
        try WBDataScenarios.overlappingRefreshBalancesBusy()
    }

    func testQueryLateSuccessIsIgnored() throws {
        try WBDataScenarios.queryLateSuccessIsIgnored()
    }

    func testQueryLateFailureIsIgnored() throws {
        try WBDataScenarios.queryLateFailureIsIgnored()
    }

    func testObsoleteCurrent401StillRevokes() throws {
        try WBDataScenarios.obsoleteCurrent401StillRevokes()
    }

    func testUnknownWriteRetainsIdempotency() throws {
        try WBDataScenarios.unknownWriteRetainsIdempotency()
    }

    func testUnchangedVersionIsNotSuccess() throws {
        try WBDataScenarios.unchangedVersionIsNotSuccess()
    }

    func testReworkRequiresOriginalContext() throws {
        try WBDataScenarios.reworkRequiresOriginalContext()
    }

    func testLateWriteDoesNotMixDemoDataset() throws {
        try WBDataScenarios.lateWriteDoesNotMixDemoDataset()
    }

    func testOfflineBoundariesStayExplicit() throws {
        try WBDataScenarios.offlineBoundariesStayExplicit()
    }

    func testReleaseEndpointIsReadOnly() throws {
        try WBDataScenarios.releaseEndpointIsReadOnly()
    }

    func testIsolatedLiveAPI() async throws {
        guard let configured = ProcessInfo.processInfo.environment["WB_INTEGRATION_URL"] else {
            throw XCTSkip("仅显式注入隔离服务地址时执行真实网络联调")
        }
        let endpoint = try WBEnvironment.validate(configured, requireHTTPS: false)
        guard let components = URLComponents(string: endpoint), components.host == "127.0.0.1",
            let port = components.port, port > 0, port != 8098
        else {
            throw WBError.unavailable("联调仅允许显式端口的127.0.0.1隔离服务，禁止8098")
        }
        let environment = WBEnvironment(endpoint: endpoint, timeout: 2.5, editable: true)
        let store = WBStore(transport: WBJobsTransport(), environment: environment)
        defer {
            store.logout()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: "admin", password: "Demo-Repair-2026!") { result in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(with: result)
            }
        }
        XCTAssertFalse(store.isDemo, store.lastMessage)
        XCTAssertEqual(store.actor?.role, "admin")
        guard !store.isDemo, store.actor?.role == "admin",
            let customerOrder = store.orders.first(where: {
                $0.customerId == "customer" && $0.companyId == "company-a"
            })
        else {
            throw WBError.invalidResponse("隔离服务未返回真实授权客户样例，禁止继续写入")
        }

        let detail = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WBOrder, Error>) in
            store.loadOrder(id: customerOrder.id) { result in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(with: result)
            }
        }
        XCTAssertEqual(detail.id, customerOrder.id)
        XCTAssertFalse(detail.isSummary)

        let marker = "iOS隔离联调-" + UUID().uuidString
        let input = WBOrderInput()
            .byType("mail")
            .byCustomer(customerOrder.customer)
            .byCustomerId(customerOrder.customerId)
            .byCompanyId(customerOrder.companyId)
            .byProject("仅隔离服务合成验证")
            .byDevice(marker)
            .byDescription("真实JobsNetworking链路创建的合成维修单")
        let created = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WBOrder, Error>) in
            store.createOrder(input: input) { result in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(with: result)
            }
        }
        XCTAssertFalse(store.isDemo)
        XCTAssertFalse(created.id.hasPrefix("ios-demo-"))
        XCTAssertNotEqual(created.id, customerOrder.id)
        XCTAssertEqual(created.version, 1)
        XCTAssertEqual(created.device, marker)
        XCTAssertEqual(created.customerId, customerOrder.customerId)

        let persisted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WBOrder, Error>) in
            store.loadOrder(id: created.id) { result in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(with: result)
            }
        }
        XCTAssertEqual(persisted.id, created.id)
        XCTAssertEqual(persisted.device, marker)
        XCTAssertEqual(persisted.description, input.description)
        XCTAssertFalse(persisted.isSummary)

        let rejectedStore = WBStore(transport: WBJobsTransport(), environment: environment)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                rejectedStore.login(username: "admin", password: "invalid-" + UUID().uuidString) { result in
                    XCTAssertTrue(Thread.isMainThread)
                    continuation.resume(with: result)
                }
            }
            XCTFail("真实401错误密码不得回退为演示登录成功")
        } catch let error as WBError {
            XCTAssertTrue(error.isUnauthorized, error.localizedDescription)
        }
        XCTAssertNil(rejectedStore.actor)
        XCTAssertTrue(rejectedStore.orders.isEmpty)
        XCTAssertFalse(rejectedStore.isBusy)
    }

    func testSignatureRendererExportsBoundedPixelDimensions() throws {
        let size = CGSize(width: 640, height: 240)
        let image = UIGraphicsImageRenderer.make(size: size).image { context in
            context.cgContext.setFillColor(JobsCor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            context.cgContext.setStrokeColor(JobsCor.black.cgColor)
            context.cgContext.setLineWidth(3)
            context.cgContext.move(to: CGPoint(x: 20, y: 120))
            context.cgContext.addLine(to: CGPoint(x: 620, y: 80))
            context.cgContext.strokePath()
        }
        let rendered = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(rendered.width, 640)
        XCTAssertEqual(rendered.height, 240)

        let png = try XCTUnwrap(image.pngData())
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let exported = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(exported.width, 640)
        XCTAssertEqual(exported.height, 240)
    }
}
