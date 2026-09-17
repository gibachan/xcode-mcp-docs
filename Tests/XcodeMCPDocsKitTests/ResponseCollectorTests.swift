import Foundation
import XCTest
@testable import XcodeMCPDocsKit

final class ResponseCollectorTests: XCTestCase {
    func testMatchesResponseByID() {
        let collector = ResponseCollector()
        collector.ingest(Data(#"{"id":1,"result":{"a":1}}"#.utf8) + Data("\n".utf8))
        collector.ingest(Data(#"{"id":2,"result":{"b":2}}"#.utf8) + Data("\n".utf8))

        let response = collector.wait(id: 2, timeout: 1)
        XCTAssertEqual(response.map { String(decoding: $0, as: UTF8.self) }, #"{"id":2,"result":{"b":2}}"#)
    }

    /// A response split across several chunks is parsed once the full line has arrived.
    func testReassemblesSplitChunks() {
        let collector = ResponseCollector()
        collector.ingest(Data(#"{"id":7,"resu"#.utf8))
        XCTAssertNil(collector.wait(id: 7, timeout: 0.1))

        collector.ingest(Data("lt\":{}}\n".utf8))
        XCTAssertNotNil(collector.wait(id: 7, timeout: 1))
    }

    func testIgnoresNotificationsWithoutID() {
        let collector = ResponseCollector()
        collector.ingest(Data(#"{"method":"notifications/message"}"# .utf8) + Data("\n".utf8))
        XCTAssertNil(collector.wait(id: 1, timeout: 0.1))
    }

    func testTimesOutWhenResponseNeverArrives() {
        let collector = ResponseCollector()
        let start = Date()
        XCTAssertNil(collector.wait(id: 99, timeout: 0.2))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.2)
    }

    /// When the process exits first, waiters are released instead of blocking on.
    func testFinishReleasesWaiters() {
        let collector = ResponseCollector()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            collector.finish()
        }
        let start = Date()
        XCTAssertNil(collector.wait(id: 42, timeout: 10))
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
}
