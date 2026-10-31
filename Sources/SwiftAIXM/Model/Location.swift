/// A WGS-84 horizontal position.
public struct Location: Sendable, Codable, Hashable {

  /// Latitude in decimal degrees, positive north.
  public let latitudeDeg: Double

  /// Longitude in decimal degrees, positive east.
  public let longitudeDeg: Double

  /// Creates a location from decimal degrees.
  /// - Parameters:
  ///   - latitudeDeg: Latitude in decimal degrees, positive north.
  ///   - longitudeDeg: Longitude in decimal degrees, positive east.
  public init(latitudeDeg: Double, longitudeDeg: Double) {
    self.latitudeDeg = latitudeDeg
    self.longitudeDeg = longitudeDeg
  }
}
