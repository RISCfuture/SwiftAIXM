/// The kind of aerodrome an ``Airport`` record describes.
public enum AirportType: String, Sendable, Codable, CaseIterable {

  /// An aerodrome only.
  case aerodrome = "AD"

  /// An aerodrome with heliport facilities.
  case aerodromeAndHeliport = "AH"

  /// A heliport only.
  case heliport = "HP"

  /// A landing site.
  case landingSite = "LS"

  /// A glider site (open flightmaps extension).
  case gliderSite = "GLD"

  /// An ultralight site (open flightmaps extension).
  case ultralightSite = "UL"

  /// An emergency landing site (open flightmaps extension).
  case emergencyLandingSite = "ELS"

  /// A kind the data set describes as `OTHER`.
  case other = "OTHER"

  /// Whether the aerodrome serves fixed-wing aircraft.
  public var hasRunways: Bool { self == .aerodrome || self == .aerodromeAndHeliport }

  /// Reads a code as written in an AIXM 5.1 or OFMX data set.
  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self(otherCode: code) else { return nil }
    self = value
  }
}
