#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import AsyncHTTPClient
import Fetch
import HTTPTypes
import NIOCore
import NIOHTTP1

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension FetchClient {
  public static func asyncHTTPClient(_ client: HTTPClient) -> Self {
    Self { request in
      var clientRequest = HTTPClientRequest(url: request.url.absoluteString)
      clientRequest.method = HTTPMethod(rawValue: request.method.rawValue)

      for field in request.headers {
        clientRequest.headers.add(name: field.name.rawName, value: field.value)
      }

      if let body = request.body {
        if clientRequest.headers["content-type"].isEmpty, let contentType = body.contentType {
          clientRequest.headers.add(name: "content-type", value: contentType)
        }

        clientRequest.body = .stream(
          RequestBodySequence(stream: body.stream),
          length: body.contentLength.map(HTTPClientRequest.Body.Length.known) ?? .unknown
        )
      }

      let response = try await client.execute(clientRequest, timeout: .seconds(30))

      return Response(
        status: Status(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase),
        headers: Headers(response.headers),
        body: BodyStream { continuation in
          Task {
            do {
              for try await buffer in response.body {
                continuation.yield(Array(buffer.readableBytesView))
              }
              continuation.finish()
            } catch {
              continuation.finish(throwing: error)
            }
          }
        }
      )
    }
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private struct RequestBodySequence: AsyncSequence, Sendable {
  typealias Element = ByteBuffer

  let stream: BodyStream

  func makeAsyncIterator() -> Iterator {
    Iterator(base: self.stream.makeAsyncIterator())
  }

  struct Iterator: AsyncIteratorProtocol {
    var base: BodyStream.AsyncIterator

    mutating func next() async throws -> ByteBuffer? {
      guard let bytes = try await self.base.next() else {
        return nil
      }
      return ByteBuffer(bytes: bytes)
    }
  }
}

private extension Headers {
  init(_ headers: HTTPHeaders) {
    self.init()

    for header in headers {
      if let fieldName = HTTPField.Name(header.name) {
        self[fieldName] = header.value
      }
    }
  }
}
