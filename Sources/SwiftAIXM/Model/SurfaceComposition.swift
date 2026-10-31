/// The material a runway surface is made of.
public enum SurfaceComposition: String, Sendable, Codable, CaseIterable {

  /// Asphalt.
  case asphalt = "ASPH"

  /// Asphalt and grass.
  case asphaltAndGrass = "ASPH_GRASS"

  /// Concrete.
  case concrete = "CONC"

  /// Concrete and asphalt.
  case concreteAndAsphalt = "CONC_ASPH"

  /// Concrete and grass.
  case concreteAndGrass = "CONC_GRS"

  /// Grass.
  case grass = "GRASS"

  /// Sand.
  case sand = "SAND"

  /// Water.
  case water = "WATER"

  /// Bituminous surface.
  case bitumen = "BITUM"

  /// Brick.
  case brick = "BRICK"

  /// Macadam.
  case macadam = "MACADAM"

  /// Stone.
  case stone = "STONE"

  /// Coral.
  case coral = "CORAL"

  /// Clay.
  case clay = "CLAY"

  /// Laterite.
  case laterite = "LATERITE"

  /// Gravel.
  case gravel = "GRAVEL"

  /// Graded or rolled earth (AIXM 4.5).
  case gradedEarth = "GRADE"

  /// Earth.
  case earth = "EARTH"

  /// Ice.
  case ice = "ICE"

  /// Snow.
  case snow = "SNOW"

  /// A membrane laid over the ground.
  case membrane = "MEMBRANE"

  /// Metal.
  case metal = "METAL"

  /// Landing mats.
  case mats = "MATS"

  /// Pierced steel planking.
  case piercedSteel = "PIERCED_STEEL"

  /// Wood.
  case wood = "WOOD"

  /// A non-bituminous mix.
  case nonBituminousMix = "NON_BITUM_MIX"

  /// A material the data set describes as `OTHER`.
  case other = "OTHER"

  /// AIXM 4.5 and open flightmaps spellings of AIXM 5.1 codes.
  private static let AIXM45Codes: [String: Self] = [
    "ASP+GRS": .asphaltAndGrass,
    "CONC+ASPH": .concreteAndAsphalt,
    "CONC+GRS": .concreteAndGrass,
    "GRAVE": .gravel,
    "PSP": .piercedSteel
  ]

  /// Whether the surface is sealed.
  public var isPaved: Bool {
    switch self {
      case .asphalt, .concrete, .concreteAndAsphalt, .bitumen, .brick, .macadam, .metal,
        .piercedSteel, .nonBituminousMix:
        true
      default: false
    }
  }

  /// Reads a code as written in an AIXM 5.1, AIXM 4.5, or OFMX data set.
  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self.AIXM45Codes[code] ?? Self(otherCode: code) else {
      return nil
    }
    self = value
  }
}
