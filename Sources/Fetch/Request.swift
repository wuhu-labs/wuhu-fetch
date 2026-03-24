#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import HTTPTypes

public struct Request: Sendable {
  public var url: URL
  public var method: Method
  public var headers: Headers
  public var body: Body?

  public init(
    url: URL,
    method: Method = .get,
    headers: Headers = Headers(),
    body: Body? = nil
  ) {
    self.url = url
    self.method = method
    self.headers = headers
    self.body = body
  }
}

extension Request {
  public var isReplayable: Bool {
    self.body?.isReplayable ?? true
  }

  public func replay() -> Self? {
    if let body = self.body {
      guard let replayedBody = body.replay() else {
        return nil
      }

      return Self(
        url: self.url,
        method: self.method,
        headers: self.headers,
        body: replayedBody
      )
    } else {
      return self
    }
  }
}
