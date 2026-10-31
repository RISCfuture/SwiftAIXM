/// The kind of structure an ``Obstacle`` is.
public struct ObstacleType: CodeList {

  /// An antenna.
  public static let antenna = Self(rawValue: "ANTENNA")

  /// A building.
  public static let building = Self(rawValue: "BUILDING")

  /// A cable car or aerial ropeway.
  public static let cableCar = Self(rawValue: "CABLE_CAR")

  /// A chimney or stack.
  public static let stack = Self(rawValue: "STACK")

  /// A crane.
  public static let crane = Self(rawValue: "CRANE")

  /// A mast.
  public static let mast = Self(rawValue: "MAST")

  /// A tower.
  public static let tower = Self(rawValue: "TOWER")

  /// A power or transmission line.
  public static let transmissionLine = Self(rawValue: "TRANSMISSION_LINE")

  /// A tree or other vegetation.
  public static let vegetation = Self(rawValue: "VEGETATION")

  /// A wind turbine.
  public static let windTurbine = Self(rawValue: "WINDMILL")

  /// A wind farm.
  public static let windFarm = Self(rawValue: "WINDMILL_FARMS")

  /// An unspecified structure.
  public static let other = Self(rawValue: "OTHER")

  private static let aliases = [
    "CHIMNEY": "STACK",
    "WINDTURBINE": "WINDMILL",
    "TREE": "VEGETATION"
  ]

  /// The code as written in AIXM 5.1.
  public let rawValue: String

  /// Creates a value from its code as written in the data set.
  public init(rawValue: String) {
    self.rawValue = Self.aliases[rawValue] ?? rawValue
  }
}
