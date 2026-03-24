import _Concurrency

public struct BodyStream: AsyncSequence, Sendable {
  public typealias Element = Bytes
  public struct AsyncIterator: AsyncIteratorProtocol {
    private let _next: @Sendable () async throws -> Element?

    init(_ next: @escaping @Sendable () async throws -> Element?) {
      self._next = next
    }

    public mutating func next() async throws -> Element? {
      try await self._next()
    }
  }

  private let makeIterator: @Sendable () -> AsyncIterator

  public init(
    _ build: @escaping @Sendable (AsyncThrowingStream<Element, Error>.Continuation) -> Void
  ) {
    let stream = AsyncThrowingStream(
      Element.self,
      bufferingPolicy: .unbounded,
      build
    )
    self.makeIterator = {
      let iterator = _BodyStreamIteratorBox(base: stream.makeAsyncIterator())
      return AsyncIterator {
        try await iterator.next()
      }
    }
  }

  private init(makeIterator: @escaping @Sendable () -> AsyncIterator) {
    self.makeIterator = makeIterator
  }

  public func makeAsyncIterator() -> AsyncIterator {
    self.makeIterator()
  }
}

extension BodyStream {
  public static var empty: Self {
    Self { continuation in
      continuation.finish()
    }
  }

  public static func chunk(_ bytes: Bytes) -> Self {
    Self { continuation in
      if !bytes.isEmpty {
        continuation.yield(bytes)
      }
      continuation.finish()
    }
  }

  public static func chunks(_ chunks: [Bytes]) -> Self {
    Self { continuation in
      for chunk in chunks where !chunk.isEmpty {
        continuation.yield(chunk)
      }
      continuation.finish()
    }
  }

  public static func stream<S: AsyncSequence & Sendable>(_ sequence: S) -> Self
  where S.Element == Bytes {
    Self(
      makeIterator: {
        let iterator = _BodyStreamIteratorBox(base: sequence.makeAsyncIterator())
        return AsyncIterator {
          try await iterator.next()
        }
      }
    )
  }
}

private final class _BodyStreamIteratorBox<Base: AsyncIteratorProtocol>: @unchecked Sendable
where Base.Element == BodyStream.Element {
  private var base: Base

  init(base: Base) {
    self.base = base
  }

  func next() async throws -> BodyStream.Element? {
    try await self.base.next()
  }
}
