import Foundation
import SwiftAIXM

/// Groups the record errors a run reports, by what they have in common.
final class ErrorCollector {
  private var groupsByKey = [ErrorGroup.Key: ErrorGroup]()

  /// Every group, in a stable order.
  var groups: [ErrorGroup] {
    groupsByKey.sorted { $0.key < $1.key }.map(\.value)
  }

  /// The group an error belongs in, the record it names, and a value to keep as a sample.
  private static func classify(
    _ error: any Error
  ) -> (key: ErrorGroup.Key, record: String, sample: String?) {
    switch error as? AIXMRecordError {
      case let .missingValue(feature, id, field):
        return (.init(kind: .missingValue, feature: feature, field: field, value: nil), id, nil)
      case let .invalidValue(feature, id, field, value):
        let isCode = Double(value) == nil
        return (
          .init(kind: .invalidValue, feature: feature, field: field, value: isCode ? value : nil),
          id,
          isCode ? nil : value
        )
      case let .unresolvedReference(feature, id, reference):
        return (
          .init(kind: .unresolvedReference, feature: feature, field: nil, value: nil),
          id,
          reference
        )
      case nil:
        let type = String(describing: type(of: error))
        return (
          .init(kind: .other, feature: type, field: nil, value: error.localizedDescription),
          "",
          nil
        )
    }
  }

  private static func append(_ sample: String, to samples: inout [String]) {
    guard samples.count < ErrorGroup.sampleLimit, !samples.contains(sample) else { return }
    samples.append(sample)
  }

  /// Records an error reported while reading the named source.
  func record(_ error: any Error, source: String) {
    let (key, record, sample) = Self.classify(error)
    var group = groupsByKey[key] ?? ErrorGroup(key: key)
    group.count += 1
    if !group.sources.contains(source) { group.sources.append(source) }
    Self.append(record, to: &group.sampleRecords)
    if let sample { Self.append(sample, to: &group.sampleValues) }
    groupsByKey[key] = group
  }
}
