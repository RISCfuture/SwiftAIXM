import SwiftAIXM

/// A count the report records for each data set, so that a cycle in which records quietly go
/// missing shows up against the one before.
enum Measure: String, CaseIterable {
  case airports
  case runways
  case runwayDirections
  case thresholds
  case thresholdElevations
  case TORA
  case TODA
  case ASDA
  case LDA
  case glidepaths
  case visualGlideSlopes
  case obstacles
  case obstacleParts
  case obstacleTopElevations

  /// The count of this measure in a data set.
  func count(in dataset: AIXMDataset) -> Int {
    let directions = dataset.airports.flatMap(\.runways).flatMap(\.directions)
    let parts = dataset.obstacles.flatMap(\.parts)
    switch self {
      case .airports: return dataset.airports.count
      case .runways: return dataset.airports.flatMap(\.runways).count
      case .runwayDirections: return directions.count
      case .thresholds: return directions.count { ($0.threshold ?? $0.displacedThreshold) != nil }
      case .thresholdElevations:
        return directions.count { ($0.threshold ?? $0.displacedThreshold)?.elevation != nil }
      case .TORA: return directions.count { $0.declaredDistances.TORA != nil }
      case .TODA: return directions.count { $0.declaredDistances.TODA != nil }
      case .ASDA: return directions.count { $0.declaredDistances.ASDA != nil }
      case .LDA: return directions.count { $0.declaredDistances.LDA != nil }
      case .glidepaths: return directions.count { $0.glidepath != nil }
      case .visualGlideSlopes: return directions.count { $0.visualGlideSlope != nil }
      case .obstacles: return dataset.obstacles.count
      case .obstacleParts: return parts.count
      case .obstacleTopElevations: return parts.count { $0.topElevation != nil }
    }
  }
}
