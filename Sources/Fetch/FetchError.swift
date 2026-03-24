public enum FetchError: Error, Sendable {
  case unimplemented
  case unexpectedStatus(Status)
  case bodyLimitExceeded(limit: Int)
  case invalidTextEncoding
}
