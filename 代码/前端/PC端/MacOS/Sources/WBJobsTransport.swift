//
//  WBJobsTransport.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@MainActor
final class WBJobsTransport: WBTransport {
  private let session = URLSession.desktopMake()
  func download(_ request: WBRequest, completion: @escaping (Result<Data, WBError>) -> Void) {
    guard let url = URL(string: request.endpoint + "/api/v38" + request.path) else {
      completion(.failure(.unavailable("服务地址尚未配置")))
      return
    }
    var wire = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeout)
    wire.httpMethod = "GET"
    wire.allHTTPHeaderFields = request.headers
    session.dataTask(with: wire) { data, response, error in
      let result: Result<Data, WBError>
      if error != nil {
        result = .failure(.transport("网络请求未完成，请检查服务连接"))
      } else if let response = response as? HTTPURLResponse, let data {
        if !(200...299).contains(response.statusCode) {
          result = .failure(
            .server(response.statusCode, "loan_file_rejected", "HTTP \(response.statusCode)"))
        } else if ["image/png", "image/jpeg", "image/gif"].contains(response.mimeType ?? ""),
          !data.isEmpty, data.count <= 8 * 1024 * 1024
        {
          result = .success(data)
        } else {
          result = .failure(.invalidResponse("借还图片凭据响应无效"))
        }
      } else {
        result = .failure(.invalidResponse("借还图片凭据响应无效"))
      }
      Task { @MainActor in completion(result) }
    }.resume()
  }
  func send(_ request: WBRequest, completion: @escaping (Result<WBJSON, WBError>) -> Void) {
    guard let url = URL(string: request.endpoint + "/api/v38" + request.path) else {
      completion(.failure(.unavailable("服务地址尚未配置")))
      return
    }

    var wire = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeout)
    wire.httpMethod = request.method
    wire.allHTTPHeaderFields = request.headers
    if let body = request.body {
      do {
        wire.httpBody = try WBFoundation.data(body)
        wire.setValue("application/json", forHTTPHeaderField: "Content-Type")
      } catch {
        completion(.failure(.unavailable("请求内容无法编码为有效 JSON")))
        return
      }
    }

    session.dataTask(with: wire) {
      data, response, error in
      let result: Result<WBJSON, WBError>
      if error != nil {
        result = .failure(.transport("网络请求未完成，请检查服务连接"))
      } else if let http = response as? HTTPURLResponse, let data {
        let value = try? WBFoundation.decode(data)
        if !(200...299).contains(http.statusCode) {
          result = .failure(
            .server(
              http.statusCode, value?.object?["error"]?.string ?? "http_error",
              value?.object?["message"]?.string ?? "HTTP \(http.statusCode)"))
        } else if let value {
          result = .success(value)
        } else {
          result = .failure(.invalidResponse("JSON 无法解析"))
        }
      } else {
        result = .failure(.invalidResponse("JSON 无法解析"))
      }

      Task {
        @MainActor in
        completion(result)
      }
    }.resume()
  }
}
