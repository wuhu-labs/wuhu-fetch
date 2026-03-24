#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Response {
  @discardableResult
  public func validateStatus() throws -> Self {
    try self.validateStatus(200..<300)
  }

  @discardableResult
  public func validateStatus(_ range: Range<Int>) throws -> Self {
    guard range.contains(self.status.code) else {
      throw FetchError.unexpectedStatus(self.status)
    }
    return self
  }

  public func bytes(upTo limit: Int? = nil) async throws -> Bytes {
    var collected: Bytes = []

    for try await chunk in self.body {
      if let limit, collected.count + chunk.count > limit {
        throw FetchError.bodyLimitExceeded(limit: limit)
      }
      collected.append(contentsOf: chunk)
    }

    return collected
  }

  public func data(upTo limit: Int? = nil) async throws -> Data {
    Data(try await self.bytes(upTo: limit))
  }

  public func text(
    upTo limit: Int? = nil,
    encoding: String.Encoding = .utf8
  ) async throws -> String {
    let data = try await self.data(upTo: limit)
    guard let string = String(data: data, encoding: encoding) else {
      throw FetchError.invalidTextEncoding
    }
    return string
  }

  public func json<T: Decodable>(
    _ type: T.Type,
    upTo limit: Int? = nil,
    decoder: JSONDecoder = .init()
  ) async throws -> T {
    try decoder.decode(T.self, from: try await self.data(upTo: limit))
  }
}
