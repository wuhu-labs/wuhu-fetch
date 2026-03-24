public enum FetchError: Error, Sendable, Equatable {
  case unimplemented
  case unexpectedStatus(Status)
  case bodyLimitExceeded(limit: Int)
  case bodyAlreadyConsumed
  case invalidTextEncoding
}
