import _Concurrency

public struct BodyStream: AsyncSequence, Sendable {
  public typealias Element = Bytes
  public typealias AsyncIterator = AsyncThrowingStream<Element, Error>.Iterator

  private let stream: AsyncThrowingStream<Element, Error>

  public init(
    _ build: @escaping @Sendable (AsyncThrowingStream<Element, Error>.Continuation) -> Void
  ) {
    self.stream = AsyncThrowingStream(
      Element.self,
      bufferingPolicy: .unbounded,
      build
    )
  }

  init(stream: AsyncThrowingStream<Element, Error>) {
    self.stream = stream
  }

  public func makeAsyncIterator() -> AsyncIterator {
    self.stream.makeAsyncIterator()
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
    Self { continuation in
      Task {
        do {
          for try await chunk in sequence {
            continuation.yield(chunk)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
