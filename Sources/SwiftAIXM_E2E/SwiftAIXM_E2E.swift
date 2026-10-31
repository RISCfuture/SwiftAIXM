import ArgumentParser
import Foundation
import SwiftAIXM

/// Reads real data set files and reports what was parsed, as an end-to-end check.
@main
struct SwiftAIXM_E2E: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Parse AIXM 5.1 or OFMX files and summarize the result."
  )

  @Argument(help: "Data set files to parse.", transform: { URL(fileURLWithPath: $0) })
  var files: [URL]

  @Option(help: "The effective date to read time slices for (YYYY-MM-DD).")
  var date: String?

  mutating func run() throws {
    let effectiveDate =
      try date.map { try Date($0, strategy: .iso8601.year().month().day()) } ?? .now
    for file in files {
      try summarize(file, effectiveDate: effectiveDate)
    }
  }

  private func summarize(_ file: URL, effectiveDate: Date) throws {
    var errors = [String: Int]()
    let start = Date.now
    let dataset = try AIXMDataset(url: file, effectiveDate: effectiveDate) { error in
      if case let AIXMRecordError.invalidValue(feature, _, field, value) = error {
        errors["\(feature).\(field)=\(value)", default: 0] += 1
      } else if case let AIXMRecordError.missingValue(feature, _, field) = error {
        errors["\(feature).\(field) missing", default: 0] += 1
      } else {
        errors[String(describing: error).prefix { $0 != "(" }.description, default: 0] += 1
      }
    }
    let elapsed = Date.now.timeIntervalSince(start)

    let runways = dataset.airports.flatMap(\.runways)
    let directions = runways.flatMap(\.directions)
    func share(_ predicate: (RunwayDirection) -> Bool) -> String {
      guard !directions.isEmpty else { return "–" }
      let count = directions.count { predicate($0) }
      return "\(count) (\(count * 100 / directions.count)%)"
    }
    let parts = dataset.obstacles.flatMap(\.parts)

    print(
      "== \(file.lastPathComponent) [\(dataset.format.rawValue)] in \(elapsed.formatted(.number.precision(.fractionLength(1)))) s"
    )
    print(
      "airports: \(dataset.airports.count), runways: \(runways.count), directions: \(directions.count)"
    )
    print(
      "  threshold or displaced threshold: \(share { $0.threshold != nil || $0.displacedThreshold != nil })"
    )
    print(
      "  threshold elevation: \(share { ($0.threshold ?? $0.displacedThreshold)?.elevation != nil })"
    )
    print(
      "  TORA: \(share { $0.declaredDistances.TORA != nil }), TODA: \(share { $0.declaredDistances.TODA != nil }), LDA: \(share { $0.declaredDistances.LDA != nil })"
    )
    print(
      "  glidepath: \(share { $0.glidepath != nil }), visual glide slope: \(share { $0.visualGlideSlope != nil })"
    )
    print(
      "obstacles: \(dataset.obstacles.count), parts: \(parts.count), parts with top elevation: \(parts.count { $0.topElevation != nil })"
    )
    print(
      "record errors: \(errors.isEmpty ? "none" : errors.map { "\($0.key)×\($0.value)" }.sorted().joined(separator: ", "))"
    )
  }
}
