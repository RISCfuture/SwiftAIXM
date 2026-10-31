public import Foundation

/// A vertical structure that may be a hazard to aircraft.
public struct Obstacle: Sendable, Codable, Hashable, Identifiable {

  /// The record's identifier in its data set.
  public let id: String

  /// The obstacle's name or identifier as published.
  public let name: String?

  /// The kind of structure.
  public let type: ObstacleType?

  /// Whether the obstacle is lit.
  public let isLighted: Bool?

  /// The obstacle's parts. A single structure has one part; a group or a line strung
  /// between towers can have several.
  public let parts: [ObstaclePart]

  /// Creates an obstacle record.
  public init(
    id: String,
    name: String?,
    type: ObstacleType?,
    isLighted: Bool?,
    parts: [ObstaclePart]
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.isLighted = isLighted
    self.parts = parts
  }
}

/// One part of an ``Obstacle``.
public struct ObstaclePart: Sendable, Codable, Hashable {

  /// The part's footprint.
  public let geometry: ObstacleGeometry

  /// The elevation of the part's highest point above mean sea level.
  public let topElevation: Measurement<UnitLength>?

  /// The part's height above ground.
  public let height: Measurement<UnitLength>?

  /// Creates an obstacle part.
  public init(
    geometry: ObstacleGeometry,
    topElevation: Measurement<UnitLength>?,
    height: Measurement<UnitLength>?
  ) {
    self.geometry = geometry
    self.topElevation = topElevation
    self.height = height
  }
}

/// The horizontal footprint of an ``ObstaclePart``.
public enum ObstacleGeometry: Sendable, Codable, Hashable {

  /// A single point.
  case point(Location)

  /// A line through the given points, such as a cable.
  case line([Location])

  /// A polygon bounded by the given points.
  case surface([Location])

  /// Every position that defines the footprint.
  public var locations: [Location] {
    switch self {
      case .point(let location): [location]
      case .line(let locations), .surface(let locations): locations
    }
  }
}
