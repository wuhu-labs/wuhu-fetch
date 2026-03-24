#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import FetchTesting
import Testing

@Suite struct FetchTestingTests {
  @Test func startsRespondsAndStops() async throws {
    let server = try IntegrationServer.start()
    defer { server.stop() }

    let request = URLRequest(url: server.baseURL.appendingPathComponent("healthz"))
    let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == "ok")
  }
}
