#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import HTTPTypes

public struct Request: Sendable {
  public struct Body: Sendable {
    public var contentLength: Int64?
    public var contentType: String?
    public var stream: BodyStream

    public init(
      contentLength: Int64? = nil,
      contentType: String? = nil,
      stream: BodyStream
    ) {
      self.contentLength = contentLength
      self.contentType = contentType
      self.stream = stream
    }
  }

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

extension Request.Body {
  public static func bytes(
    _ bytes: Bytes,
    contentType: String? = nil
  ) -> Self {
    Self(
      contentLength: Int64(bytes.count),
      contentType: contentType,
      stream: .chunk(bytes)
    )
  }

  public static func string(
    _ string: String,
    encoding: String.Encoding = .utf8
  ) -> Self {
    let data = string.data(using: encoding) ?? Data()
    return Self(
      contentLength: Int64(data.count),
      contentType: "text/plain; charset=\(encoding.ianaCharsetName)",
      stream: .chunk(Array(data))
    )
  }

  public static func json<T: Encodable>(
    _ value: T,
    encoder: JSONEncoder = .init()
  ) throws -> Self {
    let data = try encoder.encode(value)
    return Self(
      contentLength: Int64(data.count),
      contentType: "application/json",
      stream: .chunk(Array(data))
    )
  }

  public static func stream(
    length: Int64? = nil,
    contentType: String? = nil,
    _ stream: BodyStream
  ) -> Self {
    Self(
      contentLength: length,
      contentType: contentType,
      stream: stream
    )
  }
}

private extension String.Encoding {
  var ianaCharsetName: String {
    switch self {
    case .utf8:
      return "utf-8"
    case .utf16:
      return "utf-16"
    case .utf16BigEndian:
      return "utf-16be"
    case .utf16LittleEndian:
      return "utf-16le"
    case .utf32:
      return "utf-32"
    case .utf32BigEndian:
      return "utf-32be"
    case .utf32LittleEndian:
      return "utf-32le"
    default:
      return "utf-8"
    }
  }
}
