//
//  DesktopModel.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

@MainActor
final class DesktopModel: ObservableObject {
  let store: WBStore
  @Published private(set) var localDemoAvailable = false
  @Published var revision = 0
  @Published var message = ""
  @Published var selected: WBOrder?
  @Published private(set) var selectedOrderID: String?
  @Published private(set) var orderQuery = ""
  @Published private(set) var orderStatus = ""
  @Published var language = UserDefaults.standard.string(forKey: "desktop.language") ?? "zh-Hans" {
    didSet {
      UserDefaults.standard.set(language, forKey: "desktop.language")
    }
  }

  @Published var theme = UserDefaults.standard.string(forKey: "desktop.theme") ?? "system" {
    didSet {
      UserDefaults.standard.set(theme, forKey: "desktop.theme")
    }
  }

  private var observer: UUID?
  private var identity = ""
  private var openRevision = 0
  private var healthRevision = 0
  private var formalEndpoints = Set(
    UserDefaults.standard.stringArray(forKey: "desktop.confirmedProductionEndpoints") ?? [])
  private let authTransport = WBJobsTransport()
  private let catalog: [String: [String: String]]

  var contextKey: String {
    (store.actor?.id ?? "") + ":" + String(store.actor?.authVersion ?? 0) + ":" + store.endpoint
      + ":" + String(store.isDemo)
  }

  var visibleOrders: [WBOrder] {
    store.orders.filter(matchesOrderFilter)
  }

  var visibleOpenCount: Int {
    visibleOrders.filter { $0.status != "completed" }.count
  }

  var visibleRemainingCents: Int64 {
    visibleOrders.reduce(0) { $0 + $1.summary.remainingCents }
  }

  init(store: WBStore? = nil) {
    self.store = store ?? WBStore(allowsSyntheticDemo: false, requiresSyntheticPassword: true)
    let url = Bundle.main.url(forResource: "ui-l10n", withExtension: "json")!
    let raw = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any]
    var messages = raw?["messages"] as? [String: [String: String]] ?? [:]
    if let extraURL = Bundle.main.url(forResource: "desktop-l10n", withExtension: "json"),
      let extra = (try? JSONSerialization.jsonObject(with: Data(contentsOf: extraURL)))
        as? [String: Any],
      let localized = extra["messages"] as? [String: [String: String]]
    {
      for (code, words) in localized {
        messages[code, default: [:]].merge(words) {
          _, replacement in replacement
        }
      }
    }

    catalog = messages
    observer = self.store.observe {
      [weak self] in
      guard let self else {
        return
      }

      let next =
        (self.store.actor?.id ?? "") + String(self.store.actor?.authVersion ?? 0)
        + self.store.endpoint + String(self.store.isDemo)
      if next != self.identity {
        DesktopDemoMediaRegistry.clear()
        self.identity = next
        self.openRevision += 1
        self.selected = nil
        self.selectedOrderID = nil
      }

      self.reconcileOrderSelection()
      self.revision += 1
    }
  }

  func setOrderFilter(_ query: String, status: String) {
    orderQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    orderStatus = status
    reconcileOrderSelection()
    // Demo fallback publishes its full fixture; keep the same predicate at the desktop boundary.
    store.setQuery(orderQuery, status: status)
  }

  private func matchesOrderFilter(_ order: WBOrder) -> Bool {
    if orderStatus == "active" {
      guard order.status != "completed" else {
        return false
      }
    } else if !orderStatus.isEmpty && order.status != orderStatus {
      return false
    }
    guard !orderQuery.isEmpty else {
      return true
    }
    // Match the API q contract; media, raw IDs and customer notes are not search fields.
    var fields = [order.number, order.customer, order.project, order.device, order.description, order.ownerId]
    if ["admin", "dispatcher", "finance"].contains(store.actor?.role ?? "") {
      fields.append(order.remark)
    }
    return fields.joined(separator: " ").lowercased().contains(orderQuery)
  }

  private func reconcileOrderSelection() {
    guard let selectedOrderID else {
      return
    }
    guard visibleOrders.contains(where: { $0.id == selectedOrderID }),
      selected.map(matchesOrderFilter) ?? true
    else {
      openRevision += 1
      selected = nil
      self.selectedOrderID = nil
      return
    }
  }

  func timestamp(_ value: String) -> String {
    DesktopTimestamp.format(value, language: language, missing: text("时间未记录"))
  }

  func text(_ value: String) -> String {
    if language == "zh-Hans" {
      return value
    }

    return catalog[language]?[value] ?? value
  }

  func refreshDemoAvailability() {
    healthRevision += 1
    let revision = healthRevision
    let endpoint = store.endpoint
    localDemoAvailable = false
    store.setSyntheticDemoAllowed(false)
    guard Self.isLoopback(endpoint) else {
      return
    }
    authTransport.send(
      WBRequest(
        endpoint: endpoint, path: "/healthz", method: "GET", headers: [:], body: nil,
        timeout: store.timeout
      )
    ) { [weak self] result in
      guard let self, self.healthRevision == revision, self.store.endpoint == endpoint else {
        return
      }
      switch result {
      case .success(let value):
        let mode = value.object?["mode"]?.string
        if mode == "production" {
          self.formalEndpoints.insert(endpoint)
          UserDefaults.standard.set(
            Array(self.formalEndpoints), forKey: "desktop.confirmedProductionEndpoints")
        }
        self.localDemoAvailable = mode == "synthetic_demo"
      case .failure(.transport):
        self.localDemoAvailable = !self.formalEndpoints.contains(endpoint)
      case .failure:
        self.localDemoAvailable = false
      }
      self.store.setSyntheticDemoAllowed(self.localDemoAvailable)
    }
  }

  func authRequest(
    path: String,
    body: [String: Any],
    completion: @escaping (Result<WBJSON, WBError>) -> Void
  ) {
    guard !["password", "confirmPassword"].contains(where: {
      DesktopPasswordPolicy.containsEmoji(body[$0] as? String ?? "")
    }) else {
      completion(.failure(.unavailable("密码不能包含表情符号")))
      return
    }
    let endpoint = store.endpoint
    let context = contextKey
    authTransport.send(
      WBRequest(
        endpoint: endpoint, path: path, method: "POST", headers: [:], body: body,
        timeout: store.timeout
      )
    ) { [weak self] result in
      guard let self, self.store.endpoint == endpoint, self.contextKey == context else {
        completion(.failure(.stale))
        return
      }
      guard case .failure(.transport) = result, self.localDemoAvailable,
        Self.isLoopback(endpoint), !self.formalEndpoints.contains(endpoint)
      else {
        completion(result)
        return
      }
      do {
        completion(.success(try DesktopLocalDemoAuth.realm(endpoint: endpoint).perform(path: path, body: body)))
      } catch let failure as WBError {
        completion(.failure(failure))
      } catch {
        completion(.failure(.unavailable("服务连接不可用，请重试")))
      }
    }
  }

  func login(username: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard !DesktopPasswordPolicy.containsEmoji(password) else {
      completion(.failure(WBError.unavailable("密码不能包含表情符号")))
      return
    }
    let endpoint = store.endpoint
    store.login(username: username, password: password) { [weak self] result in
      guard let self, self.store.endpoint == endpoint else {
        completion(.failure(WBError.stale))
        return
      }
      guard case .failure(let error) = result, let failure = error as? WBError,
        case .transport = failure, self.localDemoAvailable, Self.isLoopback(endpoint),
        !self.formalEndpoints.contains(endpoint)
      else {
        completion(result)
        return
      }
      do {
        let realm = DesktopLocalDemoAuth.realm(endpoint: endpoint)
        let actor = try realm.login(username: username, password: password)
        try self.store.installLocalCustomerDemo(actor, username: username, password: password)
        realm.registerSession(self.store)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func loadLoanProof(
    loan: WBLoan, file: WBRecord, completion: @escaping (Result<Data, WBError>) -> Void
  ) {
    if store.isDemo {
      if let data = Data(base64Encoded: file.string("dataBase64")) {
        completion(.success(data))
      } else {
        completion(.failure(.invalidResponse("暂无图片凭据")))
      }
      return
    }
    let identity = store.actor
    let endpoint = store.endpoint
    do {
      let request = try store.loanFileRequest(loanID: loan.id, fileID: file.id)
      authTransport.download(request) { [weak self] result in
        guard let self, self.store.actor == identity, self.store.endpoint == endpoint,
          !self.store.isDemo
        else {
          completion(.failure(.stale))
          return
        }
        switch result {
        case .success(let data):
          guard data.count == Int(file.int("size")), data.count <= 8 * 1024 * 1024 else {
            completion(.failure(.invalidResponse("借还图片凭据响应无效")))
            return
          }
          completion(.success(data))
        case .failure(let error):
          if error.isUnauthorized { self.store.logout() }
          completion(.failure(error))
        }
      }
    } catch let error as WBError {
      completion(.failure(error))
    } catch {
      completion(.failure(.invalidResponse("暂无图片凭据")))
    }
  }

  private static func isLoopback(_ endpoint: String) -> Bool {
    guard let host = URLComponents(string: endpoint)?.host?.lowercased() else {
      return false
    }
    if host == "localhost" || host == "::1" || host == "[::1]" {
      return true
    }
    let components = host.split(separator: ".", omittingEmptySubsequences: false)
    return components.count == 4 && components.first == "127"
      && components.allSatisfy { UInt8($0) != nil }
  }

  func open(_ order: WBOrder) {
    guard visibleOrders.contains(where: { $0.id == order.id }), matchesOrderFilter(order) else {
      return
    }
    openRevision += 1
    selectedOrderID = order.id
    selected = nil
    let captured = openRevision
    store.loadOrder(id: order.id) {
      [weak self] result in
      guard let self, self.openRevision == captured else {
        return
      }

      switch result {
      case .success(let full):
        if self.matchesOrderFilter(full), self.visibleOrders.contains(where: { $0.id == full.id }) {
          self.selected = full
        } else {
          self.openRevision += 1
          self.selected = nil
          self.selectedOrderID = nil
        }
      case .failure(let error):
        self.message = error.localizedDescription
      }
    }
  }

  func result(_ result: Result<WBOrder, Error>) {
    switch result {
    case .success(let order):
      if matchesOrderFilter(order), visibleOrders.contains(where: { $0.id == order.id }) {
        selected = order
        selectedOrderID = order.id
      } else {
        openRevision += 1
        selected = nil
        selectedOrderID = nil
      }
      message = text("保存成功")
    case .failure(let error):
      message = error.localizedDescription
    }
  }
}
