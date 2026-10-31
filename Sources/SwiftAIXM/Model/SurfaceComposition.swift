/**
 The material a runway surface is made of.

 AIXM 4.5 (and open flightmaps) abbreviate some codes differently from AIXM 5.1;
 ``init(rawValue:)`` maps those to their AIXM 5.1 spelling.
 */
public struct SurfaceComposition: CodeList {

  /// Asphalt.
  public static let asphalt = Self(rawValue: "ASPH")

  /// Asphalt and grass.
  public static let asphaltAndGrass = Self(rawValue: "ASPH_GRASS")

  /// Concrete.
  public static let concrete = Self(rawValue: "CONC")

  /// Concrete and asphalt.
  public static let concreteAndAsphalt = Self(rawValue: "CONC_ASPH")

  /// Concrete and grass.
  public static let concreteAndGrass = Self(rawValue: "CONC_GRS")

  /// Bituminous surface.
  public static let bitumen = Self(rawValue: "BITUM")

  /// Non-bituminous mix.
  public static let nonBituminousMix = Self(rawValue: "NON_BITUM_MIX")

  /// Macadam.
  public static let macadam = Self(rawValue: "MACADAM")

  /// Brick.
  public static let brick = Self(rawValue: "BRICK")

  /// Metal.
  public static let metal = Self(rawValue: "METAL")

  /// Pierced steel planking.
  public static let piercedSteelPlanking = Self(rawValue: "PSP")

  /// Wood.
  public static let wood = Self(rawValue: "WOOD")

  /// Grass.
  public static let grass = Self(rawValue: "GRASS")

  /// Gravel.
  public static let gravel = Self(rawValue: "GRAVEL")

  /// Sand.
  public static let sand = Self(rawValue: "SAND")

  /// Earth or soil.
  public static let earth = Self(rawValue: "EARTH")

  /// Clay.
  public static let clay = Self(rawValue: "CLAY")

  /// Laterite.
  public static let laterite = Self(rawValue: "LATERITE")

  /// Coral.
  public static let coral = Self(rawValue: "CORAL")

  /// Ice.
  public static let ice = Self(rawValue: "ICE")

  /// Snow.
  public static let snow = Self(rawValue: "SNOW")

  /// Water.
  public static let water = Self(rawValue: "WATER")

  private static let aliases = [
    "GRAVE": "GRAVEL",
    "GRS": "GRASS",
    "CONC+ASPH": "CONC_ASPH",
    "CONC+GRS": "CONC_GRS",
    "ASPH+GRASS": "ASPH_GRASS"
  ]

  private static var pavedCompositions: Set<Self> {
    [
      .asphalt, .concrete, .concreteAndAsphalt, .bitumen, .nonBituminousMix, .macadam, .brick,
      .metal, .piercedSteelPlanking
    ]
  }

  /// The code as written in AIXM 5.1.
  public let rawValue: String

  /// Whether the surface is sealed: concrete, asphalt, bitumen, macadam, brick, or metal.
  public var isPaved: Bool {
    Self.pavedCompositions.contains(self)
  }

  /// Creates a value from its code as written in the data set.
  public init(rawValue: String) {
    self.rawValue = Self.aliases[rawValue] ?? rawValue
  }
}
