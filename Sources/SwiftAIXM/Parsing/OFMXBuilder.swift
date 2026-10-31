import Foundation

/**
 Builds model records from an open flightmaps OFMX snapshot.

 OFMX is a dialect of AIXM 4.5. Features identify each other by natural keys nested in
 their `…Uid` elements: an aerodrome by its code, a runway by its aerodrome and
 designator, and a runway direction by its runway and designator.

 OFMX places a runway direction's coordinates at its displaced threshold when the
 threshold is displaced (a `DPLM` declared distance) and at the threshold otherwise, so
 the point lands in ``RunwayDirection/displacedThreshold`` or
 ``RunwayDirection/threshold`` accordingly.
 */
final class OFMXBuilder: FeatureBuilder {

  /// Declared-distance day periods, in order of preference: all day, then daytime.
  private static let dayPeriods = ["A", "D"]

  let featureNames: Set<String> = ["Ahp", "Rwy", "Rdn", "Rdd", "Obs"]

  private let report: (any Error) -> Void

  private var airportNodes = [XMLNode]()
  private var runwayNodes = [XMLNode]()
  private var directionNodes = [XMLNode]()
  private var distancesByDirection = [
    String: [String: (period: String, value: Measurement<UnitLength>)]
  ]()
  private var obstacles = [Obstacle]()

  init(report: @escaping (any Error) -> Void) {
    self.report = report
  }

  private static func airportKey(_ uid: XMLNode?) -> String? {
    uid?.value("codeId")
  }

  private static func runwayKey(_ uid: XMLNode?) -> String? {
    guard let uid, let airport = airportKey(uid.child("AhpUid")),
      let designator = uid.value("txtDesig")
    else { return nil }
    return "\(airport)|\(designator)"
  }

  private static func directionKey(_ uid: XMLNode?) -> String? {
    guard let uid, let runway = runwayKey(uid.child("RwyUid")),
      let designator = uid.value("txtDesig")
    else { return nil }
    return "\(runway)|\(designator)"
  }

  private static func length(_ node: XMLNode, value: String, unit: String) -> Measurement<
    UnitLength
  >? {
    ValueParsing.length(node.value(value), unit: node.value(unit))
  }

  private static func location(_ node: XMLNode) -> Location? {
    guard let latitude = ValueParsing.hemisphereCoordinate(node.value("geoLat")),
      let longitude = ValueParsing.hemisphereCoordinate(node.value("geoLong"))
    else { return nil }
    return Location(latitudeDeg: latitude, longitudeDeg: longitude)
  }

  func consume(_ feature: XMLNode) {
    switch feature.name {
      case "Ahp": airportNodes.append(feature)
      case "Rwy": runwayNodes.append(feature)
      case "Rdn": directionNodes.append(feature)
      case "Rdd": consumeDeclaredDistance(feature)
      case "Obs": consumeObstacle(feature)
      default: break
    }
  }

  func finish() -> (airports: [Airport], obstacles: [Obstacle]) {
    let directionsByRunway = Dictionary(grouping: directionNodes.compactMap(direction)) {
      $0.runwayKey
    }
    let runwaysByAirport = Dictionary(
      grouping: runwayNodes.compactMap { node in
        runway(node, directions: { directionsByRunway[$0]?.map(\.direction) ?? [] })
      }
    ) { $0.airportKey }

    let airports = airportNodes.compactMap { node in
      airport(node) { runwaysByAirport[$0]?.map(\.runway) ?? [] }
    }
    return (airports, obstacles)
  }

  // MARK: - Features

  private func airport(_ node: XMLNode, runways: (String) -> [Runway]) -> Airport? {
    guard let key = Self.airportKey(node.child("AhpUid")) else {
      report(AIXMRecordError.missingValue(feature: "Ahp", id: "", field: "codeId"))
      return nil
    }
    return Airport(
      id: node.child("AhpUid")?.attributes["mid"] ?? key,
      designator: key,
      ICAOIdentifier: node.value("codeIcao"),
      IATAIdentifier: node.value("codeIata"),
      name: node.value("txtName") ?? key,
      city: node.value("txtNameCitySer"),
      type: node.value("codeType").map(AirportType.init) ?? .aerodrome,
      referencePoint: Self.location(node),
      elevation: Self.length(node, value: "valElev", unit: "uomDistVer"),
      magneticVariation: ValueParsing.degrees(node.value("valMagVar")),
      runways: runways(key).sorted { $0.designator < $1.designator }
    )
  }

  private func runway(
    _ node: XMLNode,
    directions: (String) -> [RunwayDirection]
  ) -> (airportKey: String, runway: Runway)? {
    guard let uid = node.child("RwyUid"), let key = Self.runwayKey(uid),
      let airportKey = Self.airportKey(uid.child("AhpUid")), let designator = uid.value("txtDesig")
    else {
      report(AIXMRecordError.missingValue(feature: "Rwy", id: "", field: "RwyUid"))
      return nil
    }
    let runway = Runway(
      id: uid.attributes["mid"] ?? key,
      designator: designator,
      isFixedWing: true,
      length: Self.length(node, value: "valLen", unit: "uomDimRwy"),
      width: Self.length(node, value: "valWid", unit: "uomDimRwy"),
      composition: node.value("codeComposition").map(SurfaceComposition.init),
      directions: directions(key).sorted { $0.designator < $1.designator }
    )
    return (airportKey, runway)
  }

  private func direction(_ node: XMLNode) -> (runwayKey: String, direction: RunwayDirection)? {
    guard let uid = node.child("RdnUid"), let key = Self.directionKey(uid),
      let runwayKey = Self.runwayKey(uid.child("RwyUid")), let designator = uid.value("txtDesig")
    else {
      report(AIXMRecordError.missingValue(feature: "Rdn", id: "", field: "RdnUid"))
      return nil
    }

    let distances = (distancesByDirection[key] ?? [:]).mapValues(\.value)
    let point = Self.location(node).map {
      RunwayPoint(location: $0, elevation: nil)
    }
    let isDisplaced = (distances["DPLM"]?.value ?? 0) > 0
    let visualGlideSlope = ValueParsing.degrees(node.value("valSlopeAngleGpVasis")).map {
      VisualGlideSlope(
        angle: $0,
        minimumEyeHeightOverThreshold: Self.length(node, value: "valMeht", unit: "uomMeht")
      )
    }

    let direction = RunwayDirection(
      id: uid.attributes["mid"] ?? key,
      designator: designator,
      trueBearing: ValueParsing.degrees(node.value("valTrueBrg")),
      magneticBearing: ValueParsing.degrees(node.value("valMagBrg")),
      threshold: isDisplaced ? nil : point,
      displacedThreshold: isDisplaced ? point : nil,
      end: nil,
      touchdownZoneElevation: Self.length(node, value: "valElevTdz", unit: "uomElevTdz"),
      declaredDistances: DeclaredDistances(
        TORA: distances["TORA"],
        TODA: distances["TODA"],
        ASDA: distances["ASDA"],
        LDA: distances["LDA"],
        thresholdDisplacement: distances["DPLM"]
      ),
      glidepath: nil,
      visualGlideSlope: visualGlideSlope
    )
    return (runwayKey, direction)
  }

  private func consumeDeclaredDistance(_ node: XMLNode) {
    guard let uid = node.child("RddUid"), let key = Self.directionKey(uid.child("RdnUid")),
      let type = uid.value("codeType"), let period = uid.value("codeDayPeriod"),
      let rank = Self.dayPeriods.firstIndex(of: period)
    else { return }
    guard let value = Self.length(node, value: "valDist", unit: "uomDist") else {
      report(
        AIXMRecordError.invalidValue(
          feature: "Rdd",
          id: key,
          field: "valDist",
          value: node.value("valDist") ?? ""
        )
      )
      return
    }

    if let existing = distancesByDirection[key]?[type],
      let existingRank = Self.dayPeriods.firstIndex(of: existing.period),
      existingRank <= rank
    {
      return
    }
    distancesByDirection[key, default: [:]][type] = (period, value)
  }

  private func consumeObstacle(_ node: XMLNode) {
    guard let uid = node.child("ObsUid"), let location = Self.location(uid) else {
      report(AIXMRecordError.missingValue(feature: "Obs", id: "", field: "ObsUid"))
      return
    }
    obstacles.append(
      Obstacle(
        id: uid.attributes["mid"] ?? "\(location.latitudeDeg),\(location.longitudeDeg)",
        name: node.value("txtName"),
        type: node.value("codeType").map(ObstacleType.init),
        isLighted: node.value("codeLgt").map { $0 == "Y" },
        parts: [
          ObstaclePart(
            geometry: .point(location),
            topElevation: Self.length(node, value: "valElev", unit: "uomDistVer"),
            height: Self.length(node, value: "valHgt", unit: "uomDistVer")
          )
        ]
      )
    )
  }
}
