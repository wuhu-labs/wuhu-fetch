import Testing
@testable import WuhuFetch

@Test func example() async throws {
  let fetch = WuhuFetch()
  #expect(String(describing: type(of: fetch)) == "WuhuFetch")
}
