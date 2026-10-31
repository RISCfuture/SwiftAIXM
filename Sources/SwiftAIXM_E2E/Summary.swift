import Foundation

/// Prints the human-readable account of a run.
enum Summary {
  private static let percent = 100

  /// Prints what one data set held.
  static func print(_ source: SourceReport, name: String) {
    let file = source.file.flatMap { $0 == name ? nil : " (\($0))" } ?? ""
    guard source.failure == nil else {
      Swift.print("== \(name)\(file): \(source.failure ?? "")")
      return
    }

    func count(_ measure: Measure) -> Int { source.counts[measure.rawValue] ?? 0 }
    let directions = count(.runwayDirections)
    func share(_ measure: Measure) -> String {
      guard directions > 0 else { return "–" }
      return "\(count(measure)) (\(count(measure) * percent / directions)%)"
    }
    let seconds = source.durationSeconds.formatted(.number.precision(.fractionLength(1)))

    Swift.print("== \(name)\(file) [\(source.format ?? "")] in \(seconds) s")
    Swift.print(
      "airports: \(count(.airports)), runways: \(count(.runways)), directions: \(directions)"
    )
    Swift.print("  threshold or displaced threshold: \(share(.thresholds))")
    Swift.print("  threshold elevation: \(share(.thresholdElevations))")
    Swift.print("  TORA: \(share(.TORA)), TODA: \(share(.TODA)), LDA: \(share(.LDA))")
    Swift.print(
      "  glidepath: \(share(.glidepaths)), visual glide slope: \(share(.visualGlideSlopes))"
    )
    Swift.print(
      "obstacles: \(count(.obstacles)), parts: \(count(.obstacleParts)), parts with top elevation: \(count(.obstacleTopElevations))"
    )
    Swift.print("record errors: \(source.recordErrors)")
  }

  /// Prints the record errors and the verdict.
  static func print(_ report: RunReport) {
    Swift.print("== record errors")
    if report.errorGroups.isEmpty { Swift.print("none") }
    let newKeys = Set(report.newErrorGroups.map(\.key))
    for group in report.errorGroups {
      let marker = report.baselineCycle != nil && newKeys.contains(group.key) ? "NEW " : ""
      Swift.print("\(marker)\(describe(group))")
    }

    for drift in report.drift {
      Swift.print(
        "drift: \(drift.source) \(drift.measure) \(drift.was) → \(drift.now.map(String.init) ?? "missing"): \(drift.reason)"
      )
    }
    Swift.print(report.failed ? "FAILED: \(report.failureReasons.joined(separator: "; "))" : "OK")
  }

  private static func describe(_ group: ErrorGroup) -> String {
    let field = group.field.map { ".\($0)" } ?? ""
    let value = group.value.map { " = \($0)" } ?? ""
    let samples =
      group.sampleValues.isEmpty ? "" : " e.g. \(group.sampleValues.joined(separator: ", "))"
    return
      "\(group.kind.rawValue) \(group.feature)\(field)\(value) ×\(group.count)\(samples) [\(group.sources.joined(separator: ", "))]"
  }
}
