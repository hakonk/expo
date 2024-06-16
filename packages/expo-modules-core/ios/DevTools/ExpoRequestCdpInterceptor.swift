// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation

/**
 The `ExpoRequestInterceptorProtocolDelegate` implementation to
 dispatch CDP (Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/) events.
 */
public final class ExpoRequestCdpInterceptor {
  static let MAX_BODY_SIZE = 1_048_576
  private var delegate: ExpoRequestCdpInterceptorDelegate?
  internal var dispatchQueue = DispatchQueue(label: "expo.requestCdpInterceptor", qos: .utility)
  private var requestCounter = 0
  private func getRequestId() -> Int {
    defer { requestCounter += 1 }
    return requestCounter
  }
  private var tasks: [Int: CdpTaskWrapper] = [:]

  private init() {
    interceptRCTHTTPRequestHandler()
  }

  public static let shared = ExpoRequestCdpInterceptor()

  public func interceptRCTHTTPRequestHandler() {
    RCTHTTPRequestHandler.interceptCreateTask { task in
      self.dispatchQueue.async {
        let wrapper = CdpTaskWrapper(task, queue: self.dispatchQueue, createId: self.getRequestId)
        self.tasks[task.taskIdentifier] = wrapper
        if let request = task.currentRequest {
          let id = wrapper.requestId(for: request.hashValue)
          self.willSendRequest(requestId: "\(id)", task: task, request: request, redirectResponse: nil)
        }
      }
    }
    RCTHTTPRequestHandler.interceptDidReceiveData { task, data in
      self.dispatchQueue.async {
        if let request = task.currentRequest {
          // TODO: figure out limit
          let isText = (task.response as? HTTPURLResponse)?.responseIsText ?? false
          let id = self.tasks[task.taskIdentifier]?.currentRequestId() ?? -1
          self.didReceiveResponse(
            requestId: "\(id)",
            task: task,
            responseBody: data,
            isText: isText,
            responseBodyExceedsLimit: false
          )
        }
      }
    }
    RCTHTTPRequestHandler.interceptDidCompleteWithError { task, error in
      self.dispatchQueue.async {
        defer {
          self.tasks[task.taskIdentifier]?.invalidateObserveration()
          self.tasks.removeValue(forKey: task.taskIdentifier)
        }
        guard error == nil else { return }
        if let request = task.currentRequest {
          // TODO: Fix hard coded params below
          let id = self.tasks[task.taskIdentifier]?.currentRequestId() ?? -1
          self.didReceiveResponse(requestId: "\(id)",
                                  task: task,
                                  responseBody: Data(),
                                  isText: (task.response as? HTTPURLResponse)?.responseIsText ?? false,
                                  responseBodyExceedsLimit: false)
        }
      }
    }
    RCTHTTPRequestHandler.interceptWillPerformHTTPRedirection { task, response, request in
      self.dispatchQueue.async {
        let id = self.tasks[task.taskIdentifier]?.requestId(for: request.hashValue) ?? -1
        self.willSendRequest(requestId: "\(id)", task: task, request: request, redirectResponse: response)
      }
    }
  }

  public func removeInterceptFromRCTHTTPRequestHandler() {
    RCTHTTPRequestHandler.removeAllInterceptedMethods()
  }

  public func setDelegate(_ newValue: ExpoRequestCdpInterceptorDelegate?) {
    dispatchPrecondition(condition: .notOnQueue(dispatchQueue))
    dispatchQueue.sync {
      self.delegate = newValue
    }
  }

  private func dispatchEvent<T: CdpNetwork.EventParms>(_ event: CdpNetwork.Event<T>) {
    dispatchPrecondition(condition: .onQueue(dispatchQueue))
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(event), let payload = String(data: jsonData, encoding: .utf8) {
      self.delegate?.dispatch(payload)
    }
  }

  // MARK: ExpoRequestInterceptorProtocolDelegate implementations

  private func willSendRequest(requestId: String, task: URLSessionTask, request: URLRequest, redirectResponse: HTTPURLResponse?) {
    dispatchPrecondition(condition: .onQueue(dispatchQueue))
    let now = Date().timeIntervalSince1970

    let params = CdpNetwork.RequestWillBeSentParams(
      now: now,
      requestId: requestId,
      request: request,
      encodedDataLength: task.countOfBytesReceived,
      redirectResponse: redirectResponse)
    dispatchEvent(CdpNetwork.Event(method: "Network.requestWillBeSent", params: params))

    let params2 = CdpNetwork.RequestWillBeSentExtraInfoParams(now: now, requestId: requestId, request: request)
    dispatchEvent(CdpNetwork.Event(method: "Network.requestWillBeSentExtraInfo", params: params2))
  }

  private func didReceiveResponse(requestId: String, task: URLSessionTask, responseBody: Data, isText: Bool, responseBodyExceedsLimit: Bool) {
    dispatchPrecondition(condition: .onQueue(dispatchQueue))
    guard let request = task.currentRequest, let response = task.response as? HTTPURLResponse else {
      return
    }
    let now = Date().timeIntervalSince1970

    let params = CdpNetwork.ResponseReceivedParams(
      now: now,
      requestId: requestId,
      request: request,
      response: response,
      encodedDataLength: task.countOfBytesReceived)
    dispatchEvent(CdpNetwork.Event(method: "Network.responseReceived", params: params))

    if !responseBodyExceedsLimit {
      let params2 = CdpNetwork.ExpoReceivedResponseBodyParams(now: now, requestId: requestId, responseBody: responseBody, isText: isText)
      dispatchEvent(CdpNetwork.Event(method: "Expo(Network.receivedResponseBody)", params: params2))
    }

    let params3 = CdpNetwork.LoadingFinishedParams(now: now, requestId: requestId, encodedDataLength: task.countOfBytesReceived)
    dispatchEvent(CdpNetwork.Event(method: "Network.loadingFinished", params: params3))
  }
}

/**
 The delegate to dispatch CDP events for ExpoRequestCdpInterceptor
 */
@objc(EXRequestCdpInterceptorDelegate)
public protocol ExpoRequestCdpInterceptorDelegate {
  @objc
  func dispatch(_ event: String)
}

final class CdpTaskWrapper {
  typealias RequestId = Int
  private var requestIds: [Int: RequestId] = [:]
  private var observation: NSKeyValueObservation?
  private let task: URLSessionTask

  init(_ task: URLSessionTask, queue: DispatchQueue, createId: @escaping () -> Int) {
    self.task = task
    observation = task.observe(\.currentRequest, options: [.initial, .new, .old, .prior]) { [weak self] task, request in
      queue.async {
        guard let currentRequest = task.currentRequest else { return }
        if self?.requestIds[currentRequest.hashValue] == nil {
          self?.requestIds[currentRequest.hashValue] = createId()
        }
      }
    }
  }

  func allRequestIds() -> [RequestId] {
    requestIds.values.map { RequestId($0) } 
  }

  func currentRequestId() -> Int? {
    task.currentRequest.flatMap {
      requestIds[$0.hashValue]
    }
  }

  func requestId(for requestDigest: Int) -> Int? {
    requestIds[requestDigest]
  }

  func invalidateObserveration() {
    observation?.invalidate()
    observation = nil
  }

  deinit {
    invalidateObserveration()
  }
}

private extension HTTPURLResponse {
  var responseIsText: Bool {
    guard let contentType = value(forHTTPHeaderField: "Content-Type") else {
      return false
    }
    return contentType.starts(with: "text/") || contentType == "application/json"
  }
}
