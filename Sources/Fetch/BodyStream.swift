import _Concurrency

public final class BodyStream: AsyncSequence, @unchecked Sendable {
  public typealias Element = Bytes
  public struct AsyncIterator: AsyncIteratorProtocol {
    private let box: _AnyBodyStreamAsyncIteratorBox

    fileprivate init(box: _AnyBodyStreamAsyncIteratorBox) {
      self.box = box
    }

    public mutating func next() async throws -> Element? {
      try await self.box.next()
    }
  }

  private let box: _AnyBodyStreamBox

  public init(
    _ build: @escaping @Sendable (AsyncThrowingStream<Element, Error>.Continuation) -> Void
  ) {
    let stream = AsyncThrowingStream(
      Element.self,
      bufferingPolicy: .unbounded,
      build
    )
    self.box = _StreamBodyStreamBox(stream: stream)
  }

  private init(box: _AnyBodyStreamBox) {
    self.box = box
  }

  public func makeAsyncIterator() -> AsyncIterator {
    self.box.makeAsyncIterator()
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
    Self(box: _SequenceBodyStreamBox(sequence: sequence))
  }
}

private class _AnyBodyStreamBox: @unchecked Sendable {
  func makeAsyncIterator() -> BodyStream.AsyncIterator {
    fatalError("Override me")
  }
}

private class _AnyBodyStreamAsyncIteratorBox: @unchecked Sendable {
  func next() async throws -> BodyStream.Element? {
    fatalError("Override me")
  }
}

private final class _StreamBodyStreamBox: _AnyBodyStreamBox {
  let stream: AsyncThrowingStream<BodyStream.Element, Error>

  init(stream: AsyncThrowingStream<BodyStream.Element, Error>) {
    self.stream = stream
  }

  override func makeAsyncIterator() -> BodyStream.AsyncIterator {
    BodyStream.AsyncIterator(box: _BodyStreamIteratorBox(base: self.stream.makeAsyncIterator()))
  }
}

private final class _SequenceBodyStreamBox<S: AsyncSequence & Sendable>: _AnyBodyStreamBox
where S.Element == BodyStream.Element {
  let sequence: S

  init(sequence: S) {
    self.sequence = sequence
  }

  override func makeAsyncIterator() -> BodyStream.AsyncIterator {
    BodyStream.AsyncIterator(box: _BodyStreamIteratorBox(base: self.sequence.makeAsyncIterator()))
  }
}

private final class _BodyStreamIteratorBox<Base: AsyncIteratorProtocol>: _AnyBodyStreamAsyncIteratorBox
where Base.Element == BodyStream.Element {
  private var base: Base

  init(base: Base) {
    self.base = base
  }

  override func next() async throws -> BodyStream.Element? {
    try await self.base.next()
  }
}
