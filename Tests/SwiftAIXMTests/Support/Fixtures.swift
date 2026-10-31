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

  /// Reads a document written in a test, collecting the record errors it reports.
  static func dataset(
    document: String,
    effectiveDate: Date = effectiveDate
  ) throws -> (dataset: AIXMDataset, problems: [RecordProblem]) {
    var problems = [RecordProblem]()
    let dataset = try AIXMDataset(data: Data(document.utf8), effectiveDate: effectiveDate) {
      problems.append(RecordProblem($0))
    }
    return (dataset, problems)
  }

  enum FixtureError: Error {
    case missing(String)
  }
}

/// A record error reported through the error callback, in a form tests can compare.
enum RecordProblem: Equatable, CustomStringConvertible {
  case missing(feature: String, id: String, field: String)
  case invalid(feature: String, id: String, field: String, value: String)
  case unresolved(feature: String, id: String, reference: String)
  case unexpected(String)

  var description: String {
    switch self {
      case let .missing(feature, id, field): "\(feature) \(id) has no \(field)"
      case let .invalid(feature, id, field, value): "\(feature) \(id) has \(field) = \(value)"
      case let .unresolved(feature, id, reference): "\(feature) \(id) refers to \(reference)"
      case .unexpected(let error): error
    }
  }

  init(_ error: any Error) {
    switch error as? AIXMRecordError {
      case let .missingValue(feature, id, field):
        self = .missing(feature: feature, id: id, field: field)
      case let .invalidValue(feature, id, field, value):
        self = .invalid(feature: feature, id: id, field: field, value: value)
      case let .unresolvedReference(feature, id, reference):
        self = .unresolved(feature: feature, id: id, reference: reference)
      case nil:
        self = .unexpected(String(describing: error))
    }
  }
}

extension Collection {
  /// The collection's single element, or `nil` if it has none or several.
  var only: Element? { count == 1 ? first : nil }
}
