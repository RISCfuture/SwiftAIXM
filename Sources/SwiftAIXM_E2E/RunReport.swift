import Foundation
import SwiftAIXM

/// The machine-readable result of one end-to-end run, written with `--report`.
///
/// The AIRAC watch workflow reads it to decide whether a cycle parsed cleanly, and it becomes the
/// baseline the next cycle is compared against.
struct RunReport: Codable {

  /// Bumped when a field changes meaning, so a consumer can refuse a report it cannot read.
  static let currentSchemaVersion = 1

  let schemaVersion: Int

  /// The AIRAC cycle the run read, such as `2611`.
  let cycle: String

  /// The date time slices were read for, as `YYYY-MM-DD`.
  let effectiveDate: String

  let finishedAt: Date

  /// Each data set read, keyed by source name.
  let sources: [String: SourceReport]

  /// Every record error, grouped so that the groups stay the same from cycle to cycle.
  let errorGroups: [ErrorGroup]

  /// The cycle of the report this run was compared against.
  let baselineCycle: String?

  /// The error groups the baseline did not have, or every group when there was no baseline.
  let newErrorGroups: [ErrorGroup]

  /// Counts that moved more than their tolerance against the baseline.
  let drift: [Drift]

  let failed: Bool
  let failureReasons: [String]

  init(
    cycle: AIRACCycle,
    effectiveDate: Date,
    sources: [String: SourceReport],
    errorGroups: [ErrorGroup],
    baseline: Self?
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.cycle = cycle.identifier
    self.effectiveDate = effectiveDate.formatted(.iso8601.year().month().day())
    finishedAt = .now
    self.sources = sources
    self.errorGroups = errorGroups
    baselineCycle = baseline?.cycle

    let knownKeys = Set(baseline?.errorGroups.map(\.key) ?? [])
    newErrorGroups = errorGroups.filter { !knownKeys.contains($0.key) }
    drift = baseline.map { Drift.between($0.sources, and: sources) } ?? []

    failureReasons = Self.failureReasons(
      sources: sources,
      newErrorGroups: newErrorGroups,
      hasBaseline: baseline != nil
    )
    failed = !failureReasons.isEmpty
  }

  /// Reads a report written by an earlier run.
  static func read(from url: URL) throws -> Self {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Self.self, from: Data(contentsOf: url))
  }

  private static func failureReasons(
    sources: [String: SourceReport],
    newErrorGroups: [ErrorGroup],
    hasBaseline: Bool
  ) -> [String] {
    var reasons = sources.sorted { $0.key < $1.key }.compactMap { name, source in
      source.failure.map { "\(name): \($0)" }
        ?? (source.isEmpty ? "\(name): the data set holds no aerodromes or obstacles" : nil)
    }
    if !newErrorGroups.isEmpty {
      let count = newErrorGroups.count
      let groups = "\(count) record error group\(count == 1 ? "" : "s")"
      reasons.append(hasBaseline ? "\(groups) not seen in the baseline" : groups)
    }
    return reasons
  }

  /// Writes the report as JSON, creating missing intermediate directories.
  func write(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(self).write(to: url)
  }
}

/// What one data set held, or why it could not be read.
struct SourceReport: Codable {

  /// Where the data set was downloaded from, for a live source.
  let url: String?

  /// The file that was read.
  let file: String?

  /// The format the data set was read as.
  let format: String?

  /// Why the data set could not be downloaded or read.
  let failure: String?

  /// Record counts, keyed by ``Measure`` raw value.
  let counts: [String: Int]

  /// The number of record errors reported.
  let recordErrors: Int

  let durationSeconds: Double

  var isEmpty: Bool {
    failure == nil
      && counts[Measure.airports.rawValue, default: 0] == 0
      && counts[Measure.obstacles.rawValue, default: 0] == 0
  }

  init(
    url: URL?,
    file: URL,
    dataset: AIXMDataset,
    recordErrors: Int,
    durationSeconds: Double
  ) {
    self.url = url?.absoluteString
    self.file = file.lastPathComponent
    format = dataset.format.rawValue
    failure = nil
    counts = Dictionary(
      uniqueKeysWithValues: Measure.allCases.map { ($0.rawValue, $0.count(in: dataset)) }
    )
    self.recordErrors = recordErrors
    self.durationSeconds = durationSeconds
  }

  init(url: URL?, file: URL?, failure: String) {
    self.url = url?.absoluteString
    self.file = file?.lastPathComponent
    format = nil
    self.failure = failure
    counts = [:]
    recordErrors = 0
    durationSeconds = 0
  }
}

/// One kind of record error, with how often it occurred.
///
/// Errors are grouped by kind, feature, field, and value. A value is part of the group only when
/// it is a code or other text, so that an unknown code forms a group of its own; numbers and
/// references differ from record to record, so they are kept as samples instead.
struct ErrorGroup: Codable {

  /// How many sample records and values a group keeps.
  static let sampleLimit = 3

  let kind: Kind
  let feature: String
  let field: String?
  let value: String?
  var count: Int
  var sources: [String]
  var sampleRecords: [String]
  var sampleValues: [String]

  var key: Key { Key(kind: kind, feature: feature, field: field, value: value) }

  init(key: Key) {
    kind = key.kind
    feature = key.feature
    field = key.field
    value = key.value
    count = 0
    sources = []
    sampleRecords = []
    sampleValues = []
  }

  /// What went wrong with the records in a group.
  enum Kind: String, Codable, Comparable {
    case missingValue = "missing"
    case invalidValue = "invalid"
    case unresolvedReference = "unresolved"
    case other

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  /// What the records in a group have in common.
  struct Key: Hashable, Comparable {
    let kind: Kind
    let feature: String
    let field: String?
    let value: String?

    static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.feature, lhs.field ?? "", lhs.kind, lhs.value ?? "")
        < (rhs.feature, rhs.field ?? "", rhs.kind, rhs.value ?? "")
    }
  }
}

/// A count that moved more than its tolerance between two cycles.
struct Drift: Codable {

  /// The share of a count that may change between cycles before it is reported.
  private static let tolerance = 0.10

  /// Counts smaller than this in the baseline move too much from cycle to cycle to judge.
  private static let minimumBaseline = 20

  let source: String
  let measure: String
  let was: Int

  /// The count in this cycle, or `nil` when the source was not read.
  let now: Int?

  let reason: String

  private init(source: String, measure: String, was: Int, now: Int?, reason: String) {
    self.source = source
    self.measure = measure
    self.was = was
    self.now = now
    self.reason = reason
  }

  /// Every count in `current` that moved beyond tolerance from `baseline`, and every source the
  /// baseline read that `current` did not.
  static func between(
    _ baseline: [String: SourceReport],
    and current: [String: SourceReport]
  ) -> [Self] {
    baseline.sorted { $0.key < $1.key }.flatMap { name, was -> [Self] in
      guard let now = current[name], now.failure == nil else {
        guard was.failure == nil else { return [] }
        return [
          Self(
            source: name,
            measure: "source",
            was: 1,
            now: nil,
            reason: "The data set was not read this cycle."
          )
        ]
      }
      return was.counts.sorted { $0.key < $1.key }.compactMap { measure, wasCount in
        drift(source: name, measure: measure, was: wasCount, now: now.counts[measure] ?? 0)
      }
    }
  }

  private static func drift(source: String, measure: String, was: Int, now: Int) -> Self? {
    guard was >= minimumBaseline else { return nil }
    let change = Double(now - was) / Double(was)
    guard abs(change) > tolerance else { return nil }
    let percent = (abs(change) * 100).formatted(.number.precision(.fractionLength(1)))
    return Self(
      source: source,
      measure: measure,
      was: was,
      now: now,
      reason: "The count \(change < 0 ? "fell" : "rose") by \(percent)%."
    )
  }
}
