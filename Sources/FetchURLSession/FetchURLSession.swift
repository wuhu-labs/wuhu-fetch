#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Fetch
import HTTPTypes

extension FetchClient {
  public static func urlSession(_ session: URLSession = .shared) -> Self {
    Self { request in
      var urlRequest = URLRequest(url: request.url)
      urlRequest.httpMethod = request.method.rawValue

      for field in request.headers {
        urlRequest.addValue(field.value, forHTTPHeaderField: field.name.rawName)
      }

      if let body = request.body {
        if let contentType = body.contentType, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
          urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let contentLength = body.contentLength, urlRequest.value(forHTTPHeaderField: "Content-Length") == nil {
          urlRequest.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
        }
        urlRequest.httpBody = try await body.data()
      }

      #if canImport(FoundationNetworking)
      return try await bufferedResponse(
        using: session,
        request: urlRequest
      )
      #else
      if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
        return try await streamingResponse(
          using: session,
          request: urlRequest
        )
      } else {
        return try await streamingResponse(
          configuration: session.configuration,
          request: urlRequest
        )
      }
      #endif
    }
  }
}

private func bufferedResponse(
  using session: URLSession,
  request: URLRequest
) async throws -> Response {
  let (data, urlResponse) = try await session.data(for: request)

  return makeResponse(
    from: urlResponse,
    body: .bytes(Array(data), contentType: headerValue(named: "Content-Type", in: urlResponse))
  )
}

private func makeResponse(from urlResponse: URLResponse, body: Body) -> Response {
  guard let response = urlResponse as? HTTPURLResponse else {
    return Response(status: Status(code: 599), body: body)
  }

  let headers = Headers(response)

  return Response(
    status: Status(code: response.statusCode),
    headers: headers,
    body: body
  )
}

private extension Headers {
  init(_ response: HTTPURLResponse) {
    self.init()

    for (name, value) in response.allHeaderFields {
      guard
        let name = String(describing: name).split(separator: "\n").first,
        let fieldName = HTTPField.Name(String(name))
      else {
        continue
      }

      self[fieldName] = String(describing: value)
    }
  }
}

private func headerValue(named field: String, in response: URLResponse) -> String? {
  (response as? HTTPURLResponse)?.value(forHTTPHeaderField: field)
}

#if !canImport(FoundationNetworking)
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
private func streamingResponse(
  using session: URLSession,
  request: URLRequest
) async throws -> Response {
  let (bytes, urlResponse) = try await session.bytes(for: request)

  return makeResponse(
    from: urlResponse,
    body: .stream(
      length: urlResponse.expectedContentLength >= 0 ? urlResponse.expectedContentLength : nil,
      contentType: headerValue(named: "Content-Type", in: urlResponse),
      ByteSequence(base: bytes)
    )
  )
}

private func streamingResponse(
  configuration: URLSessionConfiguration,
  request: URLRequest
) async throws -> Response {
  let delegate = StreamingTaskDelegate()
  let session = URLSession(
    configuration: configuration,
    delegate: delegate,
    delegateQueue: nil
  )
  let task = session.dataTask(with: request)
  task.resume()

  let urlResponse = try await delegate.waitForResponse()

  return makeResponse(
    from: urlResponse,
    body: .stream(
      length: urlResponse.expectedContentLength >= 0 ? urlResponse.expectedContentLength : nil,
      contentType: headerValue(named: "Content-Type", in: urlResponse),
      SessionBoundSequence(session: session, base: delegate.body)
    )
  )
}

private struct ByteSequence<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Base.Element == UInt8 {
  typealias Element = Bytes

  let base: Base

  func makeAsyncIterator() -> Iterator {
    Iterator(base: self.base.makeAsyncIterator())
  }

  struct Iterator: AsyncIteratorProtocol {
    var base: Base.AsyncIterator

    mutating func next() async throws -> Bytes? {
      guard let byte = try await self.base.next() else {
        return nil
      }
      return [byte]
    }
  }
}

private struct SessionBoundSequence<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Base.Element == Bytes {
  typealias Element = Bytes

  let session: URLSession
  let base: Base

  func makeAsyncIterator() -> Iterator {
    Iterator(session: self.session, base: self.base.makeAsyncIterator())
  }

  struct Iterator: AsyncIteratorProtocol {
    let session: URLSession
    var base: Base.AsyncIterator

    mutating func next() async throws -> Bytes? {
      _ = self.session
      return try await self.base.next()
    }
  }
}

private final class StreamingTaskDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  let body: AsyncThrowingStream<Bytes, Error>

  private let state = LockedState()

  override init() {
    var continuation: AsyncThrowingStream<Bytes, Error>.Continuation!
    self.body = AsyncThrowingStream { continuation = $0 }
    self.state.bodyContinuation = continuation
  }

  func waitForResponse() async throws -> URLResponse {
    try await withCheckedThrowingContinuation { continuation in
      self.state.withLock {
        if let response = $0.response {
          continuation.resume(returning: response)
          return
        }

        if let error = $0.error {
          continuation.resume(throwing: error)
          return
        }

        $0.responseContinuation = continuation
      }
    }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    self.state.withLock {
      $0.response = response
      $0.responseContinuation?.resume(returning: response)
      $0.responseContinuation = nil
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    _ = self.state.withLock {
      $0.bodyContinuation?.yield(Array(data))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    self.state.withLock {
      if let error {
        if let responseContinuation = $0.responseContinuation {
          responseContinuation.resume(throwing: error)
          $0.responseContinuation = nil
        } else {
          $0.bodyContinuation?.finish(throwing: error)
        }
        $0.error = error
      } else {
        if let responseContinuation = $0.responseContinuation {
          responseContinuation.resume(throwing: URLError(.badServerResponse))
          $0.responseContinuation = nil
        }
        $0.bodyContinuation?.finish()
      }
      $0.bodyContinuation = nil
    }
    session.finishTasksAndInvalidate()
  }
}

private final class LockedState: @unchecked Sendable {
  var response: URLResponse?
  var error: Error?
  var responseContinuation: CheckedContinuation<URLResponse, Error>?
  var bodyContinuation: AsyncThrowingStream<Bytes, Error>.Continuation?

  private let lock = NSLock()

  func withLock<R>(_ operation: (LockedState) -> R) -> R {
    self.lock.lock()
    defer { self.lock.unlock() }
    return operation(self)
  }
}
#endif
