import Fetch

extension Response {
  public func sse() -> AsyncThrowingStream<SSEEvent, Error> {
    AsyncThrowingStream(SSEEvent.self, bufferingPolicy: .unbounded) { continuation in
      Task {
        do {
          var parser = _SSEParser()

          for try await chunk in self.body.asyncBytes() {
            let events = try parser.parse(chunk)
            for event in events {
              continuation.yield(event)
            }
          }

          for event in try parser.finish() {
            continuation.yield(event)
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
