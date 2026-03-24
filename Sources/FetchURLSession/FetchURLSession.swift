#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Fetch
import HTTPTypes

extension FetchClient {
  public static func urlSession(_ session: URLSession = .shared) -> Self {
    Self { request in
      var urlRequest = URLRequest(url: request.url)
      urlRequest.httpMethod = request.method.rawValue

      for field in request.headers {
        urlRequest.addValue(field.value, forHTTPHeaderField: field.name.rawName)
      }

      if let body = request.body {
        if let contentType = body.contentType, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
          urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let contentLength = body.contentLength, urlRequest.value(forHTTPHeaderField: "Content-Length") == nil {
          urlRequest.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
        }
        urlRequest.httpBody = try await body.data()
      }

      let (data, response) = try await session.data(for: urlRequest)
      guard let response = response as? HTTPURLResponse else {
        return Response(status: Status(code: 599), body: .bytes(Array(data)))
      }

      let headers = Headers(response)

      return Response(
        status: Status(code: response.statusCode),
        headers: headers,
        body: .bytes(Array(data), contentType: headers[.contentType])
      )
    }
  }
}

private extension Headers {
  init(_ response: HTTPURLResponse) {
    self.init()

    for (name, value) in response.allHeaderFields {
      guard
        let name = String(describing: name).split(separator: "\n").first,
        let fieldName = HTTPField.Name(String(name))
      else {
        continue
      }

      self[fieldName] = String(describing: value)
    }
  }
}
