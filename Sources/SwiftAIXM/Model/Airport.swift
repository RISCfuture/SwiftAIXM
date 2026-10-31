public import Foundation

/// An aerodrome or heliport, with its runways.
public struct Airport: Sendable, Codable, Hashable, Identifiable {

  /// The record's identifier in its data set: an AIXM 5.1 `gml:identifier` UUID, or an
  /// open flightmaps aerodrome code.
  public let id: String

  /// The aerodrome's designator. This is its ICAO location indicator when it has one, or a
  /// national code otherwise.
  public let designator: String

  /// The ICAO location indicator, if the aerodrome has one.
  public let ICAOIdentifier: String?

  /// The IATA code, if the aerodrome has one.
  public let IATAIdentifier: String?

  /// The aerodrome's name.
  public let name: String

  /// The city the aerodrome serves.
  public let city: String?

  /// The kind of aerodrome.
  public let type: AirportType?

  /// The aerodrome reference point, with the aerodrome's elevation.
  public let referencePoint: Location?

  /// The magnetic variation, positive east.
  public let magneticVariation: Measurement<UnitAngle>?

  /// The aerodrome's runways (and, for heliports, final approach and takeoff areas).
  public let runways: [Runway]

  /// Creates an aerodrome record.
  public init(
    id: String,
    designator: String,
    ICAOIdentifier: String?,
    IATAIdentifier: String?,
    name: String,
    city: String?,
    type: AirportType?,
    referencePoint: Location?,
    magneticVariation: Measurement<UnitAngle>?,
    runways: [Runway]
  ) {
    self.id = id
    self.designator = designator
    self.ICAOIdentifier = ICAOIdentifier
    self.IATAIdentifier = IATAIdentifier
    self.name = name
    self.city = city
    self.type = type
    self.referencePoint = referencePoint
    self.magneticVariation = magneticVariation
    self.runways = runways
  }
}
