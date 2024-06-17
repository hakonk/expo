// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation

/**
 The `ExpoRequestInterceptorProtocolDelegate` implementation to
 dispatch CDP (Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/) events.
 */
public final class ExpoRequestCdpInterceptor {
  static let MAX_BODY_SIZE = 1_048_576
  private var delegate: ExpoRequestCdpInterceptorDelegate?
  let dispatchQueue = DispatchQueue(label: "expo.requestCdpInterceptor", qos: .utility)
  private var requestCounter = 0
  private func getRequestId() -> Int {
    defer { requestCounter += 1 }
    return requestCounter
  }
  private var tasks: [Int: CdpTaskWrapper] = [:]

  // Should only be initialized for testing
  init() {
    interceptRCTHTTPRequestHandler()
  }

  public static let shared = ExpoRequestCdpInterceptor()

  public func createUrlSessionDelegate() -> any URLSessionDelegate {
    URLSessionDelegateAdapter(interceptor: self)
  }

  fileprivate func handleCreateTask(_ task: URLSessionTask) {
    self.dispatchQueue.async {
      let wrapper = self.getOrCreate(task)
      if let request = task.currentRequest {
        let id = wrapper.requestId(for: request.hashValue)
        self.willSendRequest(requestId: "\(id)", task: task, request: request, redirectResponse: nil)
      }
    }
  }

  @discardableResult
  private func getOrCreate(_ task: URLSessionTask) -> CdpTaskWrapper {
    if let wrapper = tasks[task.taskIdentifier] {
      return wrapper
    }
    let wrapper = CdpTaskWrapper(task, queue: dispatchQueue, createId: getRequestId)
    tasks[task.taskIdentifier] = wrapper
    return wrapper
  }

  fileprivate func handleDidReceiveData(_ task: URLSessionTask, data: Data) {
    self.dispatchQueue.async {
      if let request = task.currentRequest {
        // TODO: figure out limit
        let isText = (task.response as? HTTPURLResponse)?.responseIsText ?? false
        let id = self.getOrCreate(task).currentRequestId() ?? -1
        assert(id != -1, "No task has been registered")
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

  fileprivate func handleDidCompleteWithError(_ task: URLSessionTask, error: Error?) {
    self.dispatchQueue.async {
      defer {
        self.tasks[task.taskIdentifier]?.invalidateObserveration()
        self.tasks.removeValue(forKey: task.taskIdentifier)
      }
      guard error == nil else { return }
      if let request = task.currentRequest {
        // TODO: Fix hard coded params below
        let id = self.tasks[task.taskIdentifier]?.currentRequestId() ?? -1
        assert(id != -1, "No task has been registered")
        self.didReceiveResponse(requestId: "\(id)",
                                task: task,
                                responseBody: Data(),
                                isText: (task.response as? HTTPURLResponse)?.responseIsText ?? false,
                                responseBodyExceedsLimit: false)
      }
    }
  }

  fileprivate func handleRedirect(_ task: URLSessionTask, response: HTTPURLResponse, request: URLRequest) {
    self.dispatchQueue.async {
      let wrapper = self.getOrCreate(task)
      wrapper.registerRequest(request)
      let id = wrapper.requestId(for: request.hashValue) ?? -1
      assert(id != -1, "No task has been registered")
      self.willSendRequest(requestId: "\(id)", task: task, request: request, redirectResponse: response)
    }
  }

  private func interceptRCTHTTPRequestHandler() {
    RCTHTTPRequestHandler.interceptCreateTask { task in
      self.handleCreateTask(task)
    }
    RCTHTTPRequestHandler.interceptDidReceiveData { task, data in
      self.handleDidReceiveData(task, data: data)
    }
    RCTHTTPRequestHandler.interceptDidCompleteWithError { task, error in
      self.handleDidCompleteWithError(task, error: error)
    }
    RCTHTTPRequestHandler.interceptWillPerformHTTPRedirection { task, response, request in
      self.handleRedirect(task, response: response, request: request)
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
  private let createId: () -> Int
  private let queue: DispatchQueue

  init(_ task: URLSessionTask, queue: DispatchQueue, createId: @escaping () -> Int) {
    dispatchPrecondition(condition: .onQueue(queue))
    self.queue = queue
    self.task = task
    self.createId = createId
    observation = task.observe(\.currentRequest, options: [.initial, .new, .old, .prior]) { [weak self] task, request in
      queue.async {
        guard let currentRequest = task.currentRequest else { return }
        self?.registerRequest(currentRequest)
      }
    }
  }

  func registerRequest(_ urlRequest: URLRequest) {
    dispatchPrecondition(condition: .onQueue(queue))
    if requestIds[urlRequest.hashValue] == nil {
      requestIds[urlRequest.hashValue] = createId()
    }
  }

  func allRequestIds() -> [RequestId] {
    dispatchPrecondition(condition: .onQueue(queue))
    return requestIds.values.map { RequestId($0) }
  }

  func currentRequestId() -> Int? {
    dispatchPrecondition(condition: .onQueue(queue))
    let id = task.currentRequest.flatMap {
      requestIds[$0.hashValue]
    }
    return id
  }

  func requestId(for requestDigest: Int) -> Int? {
    dispatchPrecondition(condition: .onQueue(queue))
    return requestIds[requestDigest]
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

private final class URLSessionDelegateAdapter: NSObject, URLSessionDataDelegate {
  private let interceptor: ExpoRequestCdpInterceptor

  init(interceptor: ExpoRequestCdpInterceptor) {
    self.interceptor = interceptor
  }

  func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
    interceptor.handleCreateTask(task)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    interceptor.handleDidReceiveData(dataTask, data: data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
    interceptor.handleDidCompleteWithError(task, error: error)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
    interceptor.handleRedirect(task, response: response, request: request)
    // TOOD: assess whether this can simply be returned for all cases
    return request
  }

}
