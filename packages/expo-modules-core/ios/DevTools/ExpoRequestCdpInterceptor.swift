// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation

/**
 The `ExpoRequestInterceptorProtocolDelegate` implementation to
 dispatch CDP (Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/) events.
 */
public final class ExpoRequestCdpInterceptor {
  private var delegate: ExpoRequestCdpInterceptorDelegate?
  internal var dispatchQueue = DispatchQueue(label: "expo.requestCdpInterceptor", qos: .utility)

  private init() {
    interceptRCTHTTPRequestHandler()
  }

  public static let shared = ExpoRequestCdpInterceptor()

  public func interceptRCTHTTPRequestHandler() {
    RCTHTTPRequestHandler.interceptCreateTask { task in
      self.dispatchQueue.async {
        if let request = task.currentRequest {
          self.willSendRequest(requestId: "\(request.hashValue)", task: task, request: request, redirectResponse: nil)
        }
      }
    }
    RCTHTTPRequestHandler.interceptDidReceiveData { task, data in
      if let request = task.currentRequest {
        // TODO: figure out isText and limit
        self.didReceiveResponse(requestId: "\(request.hashValue)", task: task, responseBody: data, isText: false, responseBodyExceedsLimit: false)
      }
    }
    RCTHTTPRequestHandler.interceptSendRequest { request in
      self.dispatchQueue.async {

      }
    }
    RCTHTTPRequestHandler.interceptDidCompleteWithError { task, error in
      guard error == nil else { return }
      if let request = task.currentRequest {
        // TODO: Fix hard coded params below
        self.didReceiveResponse(requestId: "\(request.hashValue)", task: task, responseBody: Data(), isText: false, responseBodyExceedsLimit: false)
      }

    }
    RCTHTTPRequestHandler.interceptWillPerformHTTPRedirection { task, response, request in
      self.willSendRequest(requestId: "\(request.hashValue)", task: task, request: request, redirectResponse: response)
    }
    RCTHTTPRequestHandler.interceptDidReceiveResponse { task, response in
      if let request = task.currentRequest {
        self.didReceiveResponse(requestId: "\(request.hashValue)", task: task, responseBody: Data(), isText: false, responseBodyExceedsLimit: false)
      }
    }
  }

  public func removeInterceptFromRCTHTTPRequestHandler() {
    RCTHTTPRequestHandler.removeAllInterceptedMethods()
  }

  public func setDelegate(_ newValue: ExpoRequestCdpInterceptorDelegate?) {
    dispatchQueue.async {
      self.delegate = newValue
    }
  }

  private func dispatchEvent<T: CdpNetwork.EventParms>(_ event: CdpNetwork.Event<T>) {
    dispatchQueue.async {
      let encoder = JSONEncoder()
      if let jsonData = try? encoder.encode(event), let payload = String(data: jsonData, encoding: .utf8) {
        self.delegate?.dispatch(payload)
      }
    }
  }

  // MARK: ExpoRequestInterceptorProtocolDelegate implementations

  private func willSendRequest(requestId: String, task: URLSessionTask, request: URLRequest, redirectResponse: HTTPURLResponse?) {
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
