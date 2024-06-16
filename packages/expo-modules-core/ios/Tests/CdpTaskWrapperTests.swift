import XCTest
@testable import ExpoModulesCore

final class CdpTaskWrapperTests: XCTestCase {

  func testIdGenerationWorks() {
    let expectation = self.expectation(description: "wait for id generation")
    let testQueue = DispatchQueue(label: "CdpTaskWrapperTests-\(#function)")
    let task = TestTask()
    var id: Int = 0
    let wrapper = CdpTaskWrapper(task, queue: testQueue) {
      defer { id += 1 }
      return id
    }
    task.setCurrentRequest(URLRequest(url: URL(string: "https://expo.dev/path1")!))
    task.setCurrentRequest(URLRequest(url: URL(string: "https://expo.dev/path2")!))
    testQueue.async {
      let ids = wrapper.allRequestIds()
      XCTAssertTrue(ids.contains(0))
      XCTAssertTrue(ids.contains(1))
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: .pi)
  }

  func testCleanup() {
    let expectation = self.expectation(description: "wait for id generation")
    let testQueue = DispatchQueue(label: "CdpTaskWrapperTests-\(#function)")
    let task = TestTask()
    let wrapper = CdpTaskWrapper(task, queue: testQueue) {
      XCTFail("Should not be called")
      return -1
    }
    wrapper.invalidateObserveration()
    task.setCurrentRequest(URLRequest(url: URL(string: "https://expo.dev/path")!))
    testQueue.async {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: .pi)
  }

}

private final class TestTask: URLSessionTask {
  private var _currentRequest: URLRequest?
  override var currentRequest: URLRequest? {
    return _currentRequest
  }

  func setCurrentRequest(_ request: URLRequest?) {
    willChangeValue(for: \.currentRequest)
    _currentRequest = request
    didChangeValue(for: \.currentRequest)
  }
}
