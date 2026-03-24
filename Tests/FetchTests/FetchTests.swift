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
    let body = Body.string("hello")
    let response = Response(status: .ok, body: body)

    #expect(body.contentType == "text/plain; charset=utf-8")
    #expect(try await response.text() == "hello")
  }

  @Test func requestJSONBody() async throws {
    struct Payload: Codable, Equatable {
      var message: String
    }

    let body = try Body.json(Payload(message: "hi"))
    let response = Response(status: .ok, body: body)

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

  @Test func inMemoryBodiesAreReplayable() async throws {
    let body = Body.string("hello")

    #expect(body.isReplayable)
    #expect(try await body.text() == "hello")

    let replay = try #require(body.replay())
    #expect(try await replay.text() == "hello")
  }

  @Test func asyncBytesConsumesBodyOnce() async throws {
    let body = Body.chunk([1, 2, 3])

    var chunks: [Bytes] = []
    for try await chunk in body.asyncBytes() {
      chunks.append(chunk)
    }

    #expect(chunks == [[1, 2, 3]])

    do {
      _ = try await body.bytes()
      Issue.record("Expected bodyAlreadyConsumed")
    } catch let error as FetchError {
      #expect(error == .bodyAlreadyConsumed)
    }
  }
}
