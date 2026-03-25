#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Fetch
import FetchSSE
import FetchTesting
import FetchURLSession
import Testing

@Suite struct FetchURLSessionTests {
  @Test func roundTripsMethodHeadersAndBody() async throws {
    let server = try IntegrationServer.start()
    defer { server.stop() }

    var headers = Headers()
    headers[.userAgent] = "fetch-tests"
    headers[.contentType] = "text/plain; charset=utf-8"

    let request = Request(
      url: server.baseURL.appendingPathComponent("echo"),
      method: .post,
      headers: headers,
      body: .string("hello")
    )

    let response = try await FetchClient
      .urlSession(URLSession(configuration: .ephemeral))(request)
      .validateStatus()

    let payload = try await response.json(EchoPayload.self)

    #expect(payload.method == "POST")
    #expect(payload.path == "/echo")
    #expect(payload.body == "hello")
    #expect(payload.header(named: "user-agent") == "fetch-tests")
    #expect(payload.header(named: "content-type")?.contains("text/plain") == true)
  }

  @Test func mapsStatusAndBody() async throws {
    let server = try IntegrationServer.start()
    defer { server.stop() }

    let request = Request(url: server.baseURL.appendingPathComponent("status/418"))
    let response = try await FetchClient.urlSession(URLSession(configuration: .ephemeral))(request)

    #expect(response.status.code == 418)
    #expect(try await response.text() == "status:418")
  }

  @Test func streamsServerSentEventsIncrementally() async throws {
    let server = try IntegrationServer.start()
    defer { server.stop() }

    var components = URLComponents(
      url: server.baseURL.appendingPathComponent("sse-stream"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "delay", value: "0.75")
    ]

    let request = Request(url: try #require(components?.url))
    let clock = ContinuousClock()
    let start = clock.now

    let response = try await FetchClient
      .urlSession(URLSession(configuration: .ephemeral))(request)

    let responseElapsed = start.duration(to: clock.now)
    var events = response.sse().makeAsyncIterator()

    let firstEvent = try await events.next()
    let firstElapsed = start.duration(to: clock.now)
    let secondEvent = try await events.next()
    let secondElapsed = start.duration(to: clock.now)

    #if canImport(FoundationNetworking)
    #expect(responseElapsed >= .milliseconds(600))
    #expect(firstElapsed >= .milliseconds(600))
    #else
    #expect(responseElapsed < .milliseconds(400))
    #expect(firstElapsed < .milliseconds(400))
    #endif
    #expect(secondElapsed >= .milliseconds(600))
    #expect(firstEvent == SSEEvent(event: "greeting", data: "first", id: "1"))
    #expect(secondEvent == SSEEvent(event: "greeting", data: "second", id: "2"))
    #expect(try await events.next() == nil)
  }
}

private struct EchoPayload: Decodable {
  var method: String
  var path: String
  var headers: [String: String]
  var body: String

  func header(named name: String) -> String? {
    self.headers.first { key, _ in
      key.caseInsensitiveCompare(name) == .orderedSame
    }?.value
  }
}
