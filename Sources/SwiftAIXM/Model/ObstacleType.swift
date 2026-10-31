/// The kind of structure an ``Obstacle`` is.
public enum ObstacleType: String, Sendable, Codable, CaseIterable {

  /// Agricultural equipment.
  case agriculturalEquipment = "AG_EQUIP"

  /// An antenna.
  case antenna = "ANTENNA"

  /// An arch.
  case arch = "ARCH"

  /// A bridge.
  case bridge = "BRIDGE"

  /// A building.
  case building = "BUILDING"

  /// A cable car or aerial ropeway.
  case cableCar = "CABLE_CAR"

  /// An overhead catenary line.
  case catenary = "CATENARY"

  /// A compressed-air system.
  case compressedAirSystem = "COMPRESSED_AIR_SYSTEM"

  /// A control or monitoring system.
  case controlMonitoringSystem = "CONTROL_MONITORING_SYSTEM"

  /// A control tower.
  case controlTower = "CONTROL_TOWER"

  /// A cooling tower.
  case coolingTower = "COOLING_TOWER"

  /// A crane.
  case crane = "CRANE"

  /// A dam.
  case dam = "DAM"

  /// A dome.
  case dome = "DOME"

  /// An electrical exit light.
  case electricalExitLight = "ELECTRICAL_EXIT_LIGHT"

  /// An electrical system.
  case electricalSystem = "ELECTRICAL_SYSTEM"

  /// An elevator.
  case elevator = "ELEVATOR"

  /// A fence.
  case fence = "FENCE"

  /// A fuel system.
  case fuelSystem = "FUEL_SYSTEM"

  /// A gate.
  case gate = "GATE"

  /// A general utility.
  case generalUtility = "GENERAL_UTILITY"

  /// A grain elevator.
  case grainElevator = "GRAIN_ELEVATOR"

  /// A heating or cooling system.
  case heatCoolSystem = "HEAT_COOL_SYSTEM"

  /// An industrial system.
  case industrialSystem = "INDUSTRIAL_SYSTEM"

  /// A lighthouse.
  case lighthouse = "LIGHTHOUSE"

  /// A mast (open flightmaps).
  case mast = "MAST"

  /// A monument.
  case monument = "MONUMENT"

  /// A natural-gas system.
  case naturalGasSystem = "NATURAL_GAS_SYSTEM"

  /// A natural high point.
  case naturalHighPoint = "NATURAL_HIGHPOINT"

  /// A navigation aid.
  case navaid = "NAVAID"

  /// A nuclear reactor.
  case nuclearReactor = "NUCLEAR_REACTOR"

  /// A pole.
  case pole = "POLE"

  /// A power plant.
  case powerPlant = "POWER_PLANT"

  /// A refinery.
  case refinery = "REFINERY"

  /// A rig.
  case rig = "RIG"

  /// A saltwater system.
  case saltwaterSystem = "SALTWATER_SYSTEM"

  /// A sign.
  case sign = "SIGN"

  /// A spire.
  case spire = "SPIRE"

  /// A stack or chimney.
  case stack = "STACK"

  /// A stadium.
  case stadium = "STADIUM"

  /// A storm-water system.
  case stormSystem = "STORM_SYSTEM"

  /// A tank.
  case tank = "TANK"

  /// A tethered balloon.
  case tetheredBalloon = "TETHERED_BALLOON"

  /// A tower.
  case tower = "TOWER"

  /// A tramway.
  case tramway = "TRAMWAY"

  /// A power or transmission line.
  case transmissionLine = "TRANSMISSION_LINE"

  /// A tree.
  case tree = "TREE"

  /// An urban area.
  case urban = "URBAN"

  /// Vegetation.
  case vegetation = "VEGETATION"

  /// A wall.
  case wall = "WALL"

  /// A wastewater system.
  case wastewaterSystem = "WASTEWATER_SYSTEM"

  /// A water system.
  case waterSystem = "WATER_SYSTEM"

  /// A water tower.
  case waterTower = "WATER_TOWER"

  /// A wind turbine.
  case windTurbine = "WINDMILL"

  /// A wind farm.
  case windFarm = "WINDMILL_FARMS"

  /// A structure the data set describes as `OTHER`.
  case other = "OTHER"

  /// open flightmaps spellings of AIXM 5.1 codes.
  private static let OFMXCodes: [String: Self] = ["CHIMNEY": .stack, "WINDTURBINE": .windTurbine]

  /// Reads a code as written in an AIXM 5.1 or OFMX data set.
  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self.OFMXCodes[code] ?? Self(otherCode: code) else {
      return nil
    }
    self = value
  }
}
