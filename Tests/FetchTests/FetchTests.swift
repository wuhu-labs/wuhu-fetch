#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import Dependencies
import DependenciesTestSupport
import Fetch
import Testing

@Suite struct FetchTests {
  @Test func requestStringBody() async throws {
    let body = Request.Body.string("hello")
    let response = Response(status: .ok, body: body.stream)

    #expect(body.contentType == "text/plain; charset=utf-8")
    #expect(try await response.text() == "hello")
  }

  @Test func requestJSONBody() async throws {
    struct Payload: Codable, Equatable {
      var message: String
    }

    let body = try Request.Body.json(Payload(message: "hi"))
    let response = Response(status: .ok, body: body.stream)

    #expect(body.contentType == "application/json")
    #expect(try await response.json(Payload.self) == Payload(message: "hi"))
  }

  @Test func validatesStatus() throws {
    let ok = Response(status: .ok)
    let created = Response(status: .created)
    let badRequest = Response(status: .badRequest)

    #expect(try ok.validateStatus().status == .ok)
    #expect(try created.validateStatus(200..<400).status == .created)

    do {
      _ = try badRequest.validateStatus()
      Issue.record("Expected unexpected status error")
    } catch let error as FetchError {
      guard case let .unexpectedStatus(status) = error else {
        Issue.record("Unexpected error: \(error)")
        return
      }
      #expect(status == .badRequest)
    }
  }

  @Test func enforcesBodyLimit() async throws {
    let response = Response(status: .ok, body: .chunks([[1, 2], [3, 4]]))

    do {
      _ = try await response.bytes(upTo: 3)
      Issue.record("Expected body limit error")
    } catch let error as FetchError {
      guard case let .bodyLimitExceeded(limit) = error else {
        Issue.record("Unexpected error: \(error)")
        return
      }
      #expect(limit == 3)
    }
  }

  @Test func usesDependencyKey() async throws {
    let request = Request(url: URL(string: "https://example.com")!)

    let response = try await withDependencies {
      $0.fetch = FetchClient { request in
        #expect(request.url.absoluteString == "https://example.com")
        return Response(status: .ok, body: .chunk(Array("value".utf8)))
      }
    } operation: {
      @Dependency(\.fetch) var fetch
      return try await fetch(request)
    }

    #expect(try await response.text() == "value")
  }

  @Test func sequenceBackedStreamIsLazy() async throws {
    let probe = Probe()
    let body = BodyStream.stream(ProbeSequence(probe: probe))

    #expect(await probe.started == false)

    var iterator = body.makeAsyncIterator()
    #expect(try await iterator.next() == [1, 2, 3])
    #expect(await probe.started == true)
    #expect(try await iterator.next() == nil)
  }
}

private actor Probe {
  var started = false

  func markStarted() {
    self.started = true
  }
}

private struct ProbeSequence: AsyncSequence, Sendable {
  typealias Element = Bytes

  let probe: Probe

  func makeAsyncIterator() -> Iterator {
    Iterator(probe: self.probe)
  }

  struct Iterator: AsyncIteratorProtocol {
    let probe: Probe
    var hasYielded = false

    mutating func next() async throws -> Bytes? {
      guard !self.hasYielded else { return nil }
      self.hasYielded = true
      await self.probe.markStarted()
      return [1, 2, 3]
    }
  }
}
