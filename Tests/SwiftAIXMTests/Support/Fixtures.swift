import Foundation
import SwiftAIXM

/// Data set files trimmed from real publications, kept in the test bundle.
enum Fixtures {
  static let aerodrome = "aixm51-aerodrome.xml"
  static let timeSlices = "aixm51-time-slices.xml"
  static let britishObstacles = "aixm51-obstacles-uk.xml"
  static let swissObstacles = "aixm51-obstacles-ch.xml"
  static let openFlightmaps = "ofmx.ofmx"

  /// The 29 Oct 2026 AIRAC cycle the fixtures were taken from.
  static let effectiveDate = Date(timeIntervalSince1970: 1_793_232_000)

  static func url(_ name: String) throws -> URL {
    guard
      let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
    else {
      throw FixtureError.missing(name)
    }
    return url
  }

  /// Reads a fixture, collecting any record errors it reports.
  static func dataset(
    _ name: String,
    effectiveDate: Date = effectiveDate
  ) throws -> (dataset: AIXMDataset, errors: [any Error]) {
    var errors = [any Error]()
    let dataset = try AIXMDataset(url: url(name), effectiveDate: effectiveDate) {
      errors.append($0)
    }
    return (dataset, errors)
  }

  enum FixtureError: Error {
    case missing(String)
  }
}

extension Measurement where UnitType == UnitLength {
  func meters() -> Double { converted(to: .meters).value }
}
