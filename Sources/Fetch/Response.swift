import HTTPTypes

public struct Response: Sendable {
  public var status: Status
  public var headers: Headers
  public var body: BodyStream

  public init(
    status: Status,
    headers: Headers = Headers(),
    body: BodyStream = .empty
  ) {
    self.status = status
    self.headers = headers
    self.body = body
  }
}
