import Foundation
import ZIPFoundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Fetches live data sets into a working directory, reusing any already there.
struct Downloader: Sendable {
  private static let successStatus = 200

  /// Where data sets are kept.
  let directory: URL

  /// The cycle whose data sets are fetched.
  let cycle: AIRACCycle

  /// Copies the data set entries of a local archive into the working directory.
  static func extractDataSets(from archive: URL, into directory: URL) throws -> [URL] {
    let archive = try Archive(url: archive, accessMode: .read)
    return try archive.filter { isDataSet($0.path) }.map { entry in
      let destination = directory.appending(path: lastComponent(of: entry.path))
      try? FileManager.default.removeItem(at: destination)
      _ = try archive.extract(entry, to: destination)
      return destination
    }
  }

  private static func isDataSet(_ path: String) -> Bool {
    let lowercased = path.lowercased()
    return lowercased.hasSuffix(".xml") || lowercased.hasSuffix(".ofmx")
  }

  /// The file name an archive entry is extracted to. Directories in the entry's path are
  /// dropped, so an entry cannot be written outside the working directory.
  private static func lastComponent(of path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
  }

  /// The local copy of a source's data set, downloaded if it isn't there yet.
  func dataSet(for source: LiveSource) async throws -> URL {
    let destination = directory.appending(path: source.filename(cycle: cycle))
    if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
      return destination
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    switch source.location(cycle: cycle) {
      case .file(let url):
        try await download(url).write(to: destination)
      case let .linkedArchive(name, entry):
        let archive = try await download(linkedURL(named: name))
        try extract(entry, from: archive, to: destination)
    }
    return destination
  }

  private func download(_ url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    let status = (response as? HTTPURLResponse)?.statusCode
    guard status == Self.successStatus else {
      throw DownloadError.unsuccessfulResponse(url: url, status: status)
    }
    return data
  }

  /// Finds an archive among the links on the NATS data sets page. Only links to the page's
  /// own host are followed.
  private func linkedURL(named name: String) async throws -> URL {
    let page = LiveSource.NATSDataSetsPage
    let html = String(bytes: try await download(page), encoding: .utf8) ?? ""
    let links = html.matches(of: #/href="([^"]+)"/#).compactMap { match in
      URL(string: String(match.1), relativeTo: page)?.absoluteURL
    }
    guard
      let link = links.first(where: {
        $0.lastPathComponent == name && $0.host() == page.host() && $0.scheme == page.scheme
      })
    else { throw DownloadError.notLinked(name: name, page: page) }
    return link
  }

  private func extract(_ entryName: String, from data: Data, to destination: URL) throws {
    let archive = try Archive(data: data, accessMode: .read)
    guard let entry = archive.first(where: { Self.lastComponent(of: $0.path) == entryName }) else {
      throw DownloadError.missingEntry(name: entryName)
    }
    _ = try archive.extract(entry, to: destination)
  }
}

/// Reasons a live data set could not be fetched.
enum DownloadError: Error, LocalizedError {
  case unsuccessfulResponse(url: URL, status: Int?)
  case notLinked(name: String, page: URL)
  case missingEntry(name: String)

  var errorDescription: String? {
    switch self {
      case let .unsuccessfulResponse(url, status):
        "\(url.absoluteString) answered with HTTP status \(status.map(String.init) ?? "unknown")."
      case let .notLinked(name, page):
        "\(page.absoluteString) does not link \(name)."
      case .missingEntry(let name):
        "The archive does not contain \(name)."
    }
  }
}
