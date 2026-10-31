/// The kind of aerodrome an ``Airport`` record describes.
public struct AirportType: CodeList {

  /// An aerodrome only.
  public static let aerodrome = Self(rawValue: "AD")

  /// An aerodrome with heliport facilities.
  public static let aerodromeAndHeliport = Self(rawValue: "AH")

  /// A heliport only.
  public static let heliport = Self(rawValue: "HP")

  /// A landing site.
  public static let landingSite = Self(rawValue: "LS")

  /// A glider site (open flightmaps extension).
  public static let gliderSite = Self(rawValue: "GLD")

  /// An ultralight site (open flightmaps extension).
  public static let ultralightSite = Self(rawValue: "UL")

  /// The code as written in the data set.
  public let rawValue: String

  /// Whether the aerodrome serves fixed-wing aircraft.
  public var hasRunways: Bool { self == .aerodrome || self == .aerodromeAndHeliport }

  /// Creates a value from its code as written in the data set.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}
