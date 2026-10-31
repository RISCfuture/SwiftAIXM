import Testing

@testable import SwiftAIXM

@Suite
struct `Code list parsing` {
  @Test(arguments: ["OTHER", "OTHER:MAST", "OTHER:UNKNOWN", "OTHER:"])
  func `reads OTHER with or without text as other in every list`(_ code: String) {
    #expect(AirportType(code: code) == .other)
    #expect(SurfaceComposition(code: code) == .other)
    #expect(ObstacleType(code: code) == .other)
    #expect(RunwayType(code: code) == .other)
    #expect(RunwayPointRole(code: code) == .other)
    #expect(DeclaredDistanceType(code: code) == .other)
    #expect(YesNo(code: code) == .other)
  }

  @Test(arguments: ["", "OTHERS", "other", "asph", " RWY", "XYZ"])
  func `rejects codes outside every list`(_ code: String) {
    #expect(AirportType(code: code) == nil)
    #expect(SurfaceComposition(code: code) == nil)
    #expect(ObstacleType(code: code) == nil)
    #expect(RunwayType(code: code) == nil)
    #expect(RunwayPointRole(code: code) == nil)
    #expect(DeclaredDistanceType(code: code) == nil)
    #expect(YesNo(code: code) == nil)
  }

  @Test(arguments: [
    ("ASP+GRS", SurfaceComposition.asphaltAndGrass),
    ("CONC+ASPH", .concreteAndAsphalt),
    ("CONC+GRS", .concreteAndGrass),
    ("GRAVE", .gravel),
    ("PSP", .piercedSteel)
  ])
  func `reads AIXM 4.5 surface spellings`(_ code: String, _ expected: SurfaceComposition) {
    #expect(SurfaceComposition(code: code) == expected)
  }

  @Test(arguments: [("CHIMNEY", ObstacleType.stack), ("WINDTURBINE", .windTurbine)])
  func `reads open flightmaps obstacle spellings`(_ code: String, _ expected: ObstacleType) {
    #expect(ObstacleType(code: code) == expected)
  }

  @Test
  func `reads the open flightmaps threshold displacement`() {
    #expect(DeclaredDistanceType(code: "DPLM") == .thresholdDisplacement)
    #expect(DeclaredDistanceType(code: "DTHR") == .thresholdDisplacement)
  }

  @Test
  func `reads AIXM 5.1 codes that differ from their names`() {
    #expect(ObstacleType(code: "WINDMILL") == .windTurbine)
    #expect(ObstacleType(code: "WINDMILL_FARMS") == .windFarm)
    #expect(RunwayPointRole(code: "DISTHR") == .displacedThreshold)
    #expect(RunwayType(code: "FATO") == .finalApproachAndTakeoffArea)
  }

  @Test
  func `answers yes or no, and leaves OTHER unanswered`() {
    #expect(YesNo(code: "YES")?.answer == true)
    #expect(YesNo(code: "NO")?.answer == false)
    #expect(YesNo(code: "OTHER:UNKNOWN")?.answer == nil)
  }
}
