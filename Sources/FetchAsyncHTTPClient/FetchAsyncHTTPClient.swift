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
          RequestBodySequence(stream: body.asyncBytes()),
          length: body.contentLength.map(HTTPClientRequest.Body.Length.known) ?? .unknown
        )
      }

      let response = try await client.execute(clientRequest, timeout: .seconds(30))
      let headers = Headers(response.headers)

      return Response(
        status: Status(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase),
        headers: headers,
        body: .stream(
          length: firstHeaderValue(named: "content-length", in: headers).flatMap(Int64.init),
          contentType: firstHeaderValue(named: "content-type", in: headers),
          ResponseBodySequence(base: response.body)
        )
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private struct ResponseBodySequence: AsyncSequence, Sendable {
  typealias Element = Bytes

  let base: HTTPClientResponse.Body

  func makeAsyncIterator() -> Iterator {
    Iterator(base: self.base.makeAsyncIterator())
  }

  struct Iterator: AsyncIteratorProtocol {
    var base: HTTPClientResponse.Body.AsyncIterator

    mutating func next() async throws -> Bytes? {
      guard let buffer = try await self.base.next() else {
        return nil
      }
      return Array(buffer.readableBytesView)
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

private func firstHeaderValue(named rawName: String, in headers: Headers) -> String? {
  for field in headers where field.name.rawName.caseInsensitiveCompare(rawName) == .orderedSame {
    return field.value
  }
  return nil
}
