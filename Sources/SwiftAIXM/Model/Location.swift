public import Foundation

/// A WGS-84 position, with its elevation where known.
public struct Location: Sendable, Codable, Hashable {

  /// Latitude in decimal degrees, positive north.
  public let latitudeDeg: Double

  /// Longitude in decimal degrees, positive east.
  public let longitudeDeg: Double

  /// Elevation above mean sea level.
  public let elevation: Measurement<UnitLength>?

  /// Creates a location from decimal degrees.
  /// - Parameters:
  ///   - latitudeDeg: Latitude in decimal degrees, positive north.
  ///   - longitudeDeg: Longitude in decimal degrees, positive east.
  ///   - elevation: Elevation above mean sea level.
  public init(latitudeDeg: Double, longitudeDeg: Double, elevation: Measurement<UnitLength>? = nil)
  {
    self.latitudeDeg = latitudeDeg
    self.longitudeDeg = longitudeDeg
    self.elevation = elevation
  }

  /// This location with the given elevation.
  func with(elevation: Measurement<UnitLength>?) -> Self {
    Self(latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg, elevation: elevation)
  }
}
