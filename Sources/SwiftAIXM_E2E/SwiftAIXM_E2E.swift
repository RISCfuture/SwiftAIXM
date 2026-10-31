import ArgumentParser
import Foundation
import SwiftAIXM

/// Reads real data sets and reports what was parsed, as an end-to-end check.
@main
struct SwiftAIXM_E2E: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "SwiftAIXM_E2E",
    abstract: "Parse AIXM 5.1 or OFMX data sets and summarize the result.",
    discussion: """
      With files, parses each of them. Without, downloads the live data sets for the AIRAC cycle — \
      open flightmaps OFMX snapshots of every region and the NATS UK AIP and obstacle data sets — \
      into the working directory, reusing any already there, and parses those.

      Record errors are grouped by feature, field, and code, and the run fails when a data set \
      cannot be read or when an error group is not in the baseline report (every group, without a \
      baseline).
      """
  )

  @Argument(
    help: "Data set files to parse: .xml or .ofmx, or a .zip holding them.",
    transform: { URL(fileURLWithPath: $0) }
  )
  var files: [URL] = []

  @Option(help: "The AIRAC cycle: ‘effective’, ‘next’, or a cycle identifier such as 2611.")
  var cycle: AIRACCycle = .effective

  @Option(
    help: "The date to read time slices for (YYYY-MM-DD). Defaults to the cycle’s effective date."
  )
  var date: String?

  @Option(
    name: .customLong("source"),
    help: """
      A live data set to download, such as ofmx/lovv or uk/aip, or ofmx or uk for a group. Repeat \
      for several; every source by default.
      """
  )
  var sourceFilters: [String] = []

  @Option(
    help: "Where downloaded data sets are kept.",
    transform: { URL(fileURLWithPath: $0, isDirectory: true) }
  )
  var workingDirectory = URL(fileURLWithPath: ".SwiftAIXM_TestData", isDirectory: true)

  @Option(
    help: "Write a JSON report of the run to this path.",
    transform: { URL(fileURLWithPath: $0) }
  )
  var report: URL?

  @Option(
    help: "An earlier run’s JSON report to compare error groups and counts against.",
    transform: { URL(fileURLWithPath: $0) }
  )
  var baseline: URL?

  private var selectedSources: [LiveSource] {
    guard !sourceFilters.isEmpty else { return LiveSource.all }
    return LiveSource.all.filter { source in sourceFilters.contains { source.matches($0) } }
  }

  private var cycleDirectory: URL { workingDirectory.appending(path: cycle.identifier) }

  private static func describe(_ error: any Error) -> String {
    [error.localizedDescription, (error as? any LocalizedError)?.failureReason]
      .compactMap(\.self)
      .joined(separator: " ")
  }

  func validate() throws {
    if !files.isEmpty, !sourceFilters.isEmpty {
      throw ValidationError("--source selects live data sets, which are not read with files.")
    }
    for filter in sourceFilters where !LiveSource.all.contains(where: { $0.matches(filter) }) {
      throw ValidationError("No live data set is named ‘\(filter)’.")
    }
  }

  mutating func run() async throws {
    let effectiveDate =
      try date.map { try Date($0, strategy: .iso8601.year().month().day()) }
      ?? cycle.effectiveDate
    let inputs = files.isEmpty ? await downloadLiveSources() : try localInputs()

    let collector = ErrorCollector()
    var sources = [String: SourceReport]()
    for input in inputs {
      let source = read(input, effectiveDate: effectiveDate, collector: collector)
      Summary.print(source, name: input.name)
      sources[input.name] = source
    }

    let report = RunReport(
      cycle: cycle,
      effectiveDate: effectiveDate,
      sources: sources,
      errorGroups: collector.groups,
      baseline: try baseline.map { try RunReport.read(from: $0) }
    )
    Summary.print(report)
    try self.report.map { try report.write(to: $0) }
    if report.failed { throw ExitCode.failure }
  }

  private func localInputs() throws -> [Input] {
    try files.flatMap { file -> [Input] in
      guard file.pathExtension.lowercased() == "zip" else {
        return [Input(name: file.lastPathComponent, url: nil, file: .success(file))]
      }
      let directory = workingDirectory.appending(
        path: file.deletingPathExtension().lastPathComponent
      )
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return try Downloader.extractDataSets(from: file, into: directory).map {
        Input(name: $0.lastPathComponent, url: nil, file: .success($0))
      }
    }
  }

  private func downloadLiveSources() async -> [Input] {
    let downloader = Downloader(directory: cycleDirectory, cycle: cycle)
    let sources = selectedSources
    return await withTaskGroup(of: Input.self) { group in
      for source in sources {
        group.addTask { await downloader.input(for: source) }
      }
      return await group.reduce(into: []) { $0.append($1) }.sorted { $0.name < $1.name }
    }
  }

  private func read(_ input: Input, effectiveDate: Date, collector: ErrorCollector) -> SourceReport
  {
    let file: URL
    switch input.file {
      case .success(let url): file = url
      case .failure(let error):
        return SourceReport(url: input.url, file: nil, failure: Self.describe(error))
    }

    let start = Date.now
    var recordErrors = 0
    do {
      let dataset = try AIXMDataset(url: file, effectiveDate: effectiveDate) { error in
        recordErrors += 1
        collector.record(error, source: input.name)
      }
      return SourceReport(
        url: input.url,
        file: file,
        dataset: dataset,
        recordErrors: recordErrors,
        durationSeconds: Date.now.timeIntervalSince(start)
      )
    } catch {
      return SourceReport(url: input.url, file: file, failure: Self.describe(error))
    }
  }
}

/// A data set to read: a local file, or what downloading a live source produced.
struct Input: Sendable {
  let name: String

  /// Where a live data set was published.
  let url: URL?

  let file: Result<URL, any Error>
}

extension Downloader {
  /// Downloads a live source, capturing a failure instead of throwing it.
  func input(for source: LiveSource) async -> Input {
    let url: URL =
      switch source.location(cycle: cycle) {
        case .file(let url): url
        case .linkedArchive: LiveSource.NATSDataSetsPage
      }
    do {
      return Input(name: source.name, url: url, file: .success(try await dataSet(for: source)))
    } catch {
      return Input(name: source.name, url: url, file: .failure(error))
    }
  }
}
