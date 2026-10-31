import Foundation

/**
 Builds model records from an AIXM 5.1 or 5.1.1 `AIXMBasicMessage`.

 Each feature contributes the time slice in effect on the effective date: a `BASELINE`
 or `SNAPSHOT` slice whose valid time contains that date, taking the highest sequence
 and correction number when several do. Features whose lifetime has ended are dropped.
 Features refer to each other by `xlink:href`, either `urn:uuid:` identifiers or local
 `#` references, which are resolved once the whole message has been read.
 */
final class AIXM51Builder: FeatureBuilder {
  private static let currentInterpretations: Set<String> = ["BASELINE", "SNAPSHOT"]
  private static let uuidPrefix = "urn:uuid:"

  let featureNames: Set<String> = [
    "AirportHeliport", "Runway", "RunwayDirection", "RunwayCentrelinePoint", "Navaid",
    "Glidepath", "VisualGlideSlopeIndicator", "VerticalStructure"
  ]

  private let effectiveDate: Date
  private let report: (any Error) -> Void

  private var identifiersByLocalID = [String: String]()
  private var airportRecords = [AirportRecord]()
  private var runwayRecords = [RunwayRecord]()
  private var directionRecords = [DirectionRecord]()
  private var pointRecords = [PointRecord]()
  private var navaidRecords = [NavaidRecord]()
  private var glidepathsByID = [String: Glidepath]()
  private var visualGlideSlopeRecords = [(direction: Reference, indicator: VisualGlideSlope)]()
  private var obstacles = [Obstacle]()

  init(effectiveDate: Date, report: @escaping (any Error) -> Void) {
    self.effectiveDate = effectiveDate
    self.report = report
  }

  private static func lengthValue(_ node: XMLNode?) -> Measurement<UnitLength>? {
    guard let node else { return nil }
    return ValueParsing.length(node.value, unit: node.attributes["uom"])
  }

  private static func sequence(of slice: XMLNode) -> (Int, Int) {
    (
      slice.value("sequenceNumber").flatMap(Int.init) ?? 0,
      slice.value("correctionNumber").flatMap(Int.init) ?? 0
    )
  }

  private static func elevatedPoint(_ node: XMLNode?) -> RunwayPoint? {
    guard let node,
      let location = ValueParsing.positions(
        node.value("pos"),
        srsName: node.attributes["srsName"] ?? node.child("pos")?.attributes["srsName"]
      )?.first
    else { return nil }
    return RunwayPoint(location: location, elevation: lengthValue(node.child("elevation")))
  }

  func consume(_ feature: XMLNode) {
    guard let id = feature.value("identifier") else {
      report(
        AIXMRecordError.missingValue(
          feature: feature.name,
          id: feature.attributes["id"] ?? "",
          field: "gml:identifier"
        )
      )
      return
    }
    if let localID = feature.attributes["id"] { identifiersByLocalID[localID] = id }
    guard let slice = currentSlice(of: feature) else { return }

    switch feature.name {
      case "AirportHeliport": consumeAirport(id: id, slice: slice)
      case "Runway": consumeRunway(id: id, slice: slice)
      case "RunwayDirection": consumeDirection(id: id, slice: slice)
      case "RunwayCentrelinePoint": consumePoint(id: id, slice: slice)
      case "Navaid": consumeNavaid(id: id, slice: slice)
      case "Glidepath": consumeGlidepath(id: id, slice: slice)
      case "VisualGlideSlopeIndicator": consumeVisualGlideSlope(slice: slice)
      case "VerticalStructure": consumeObstacle(id: id, slice: slice)
      default: break
    }
  }

  func finish() -> (airports: [Airport], obstacles: [Obstacle]) {
    let directionsByRunway = Dictionary(grouping: linkedDirections()) { $0.runwayID }
    let runwaysByAirport = Dictionary(
      grouping: runwayRecords.compactMap { record -> (airportID: String, runway: Runway)? in
        guard let airportID = resolve(record.airport, from: "Runway", id: record.id) else {
          return nil
        }
        let directions = (directionsByRunway[record.id] ?? []).map(\.direction)
        return (airportID, record.runway(directions: directions))
      },
      by: \.airportID
    )

    let airports = airportRecords.map { record in
      record.airport(
        runways: (runwaysByAirport[record.id] ?? []).map(\.runway)
          .sorted { $0.designator < $1.designator }
      )
    }
    return (airports, obstacles)
  }

  // MARK: - Time slices

  private func currentSlice(of feature: XMLNode) -> XMLNode? {
    feature.children("timeSlice")
      .compactMap(\.children.first)
      .filter { isCurrent($0) }
      .max { Self.sequence(of: $0) < Self.sequence(of: $1) }
  }

  private func isCurrent(_ slice: XMLNode) -> Bool {
    guard let interpretation = slice.value("interpretation"),
      Self.currentInterpretations.contains(interpretation)
    else { return false }

    if let lifetimeEnd = ValueParsing.date(
      slice.value("featureLifetime", "TimePeriod", "endPosition")
    ), lifetimeEnd <= effectiveDate {
      return false
    }

    guard let period = slice.descendant("validTime", "TimePeriod") else { return true }
    if let begin = ValueParsing.date(period.value("beginPosition")), begin > effectiveDate {
      return false
    }
    if let end = ValueParsing.date(period.value("endPosition")), end <= effectiveDate {
      return false
    }
    return true
  }

  // MARK: - References

  private func reference(_ node: XMLNode?) -> Reference? {
    node?.attributes["href"].map(Reference.init)
  }

  private func resolve(_ reference: Reference?, from feature: String, id: String) -> String? {
    guard let reference else {
      report(AIXMRecordError.missingValue(feature: feature, id: id, field: "reference"))
      return nil
    }
    if reference.href.hasPrefix(Self.uuidPrefix) {
      return String(reference.href.dropFirst(Self.uuidPrefix.count))
    }
    if reference.href.hasPrefix("#"),
      let identifier = identifiersByLocalID[String(reference.href.dropFirst())]
    {
      return identifier
    }
    report(AIXMRecordError.unresolvedReference(feature: feature, id: id, reference: reference.href))
    return nil
  }

  // MARK: - Features

  private func consumeAirport(id: String, slice: XMLNode) {
    guard let designator = slice.value("designator") else {
      report(AIXMRecordError.missingValue(feature: "AirportHeliport", id: id, field: "designator"))
      return
    }
    airportRecords.append(
      AirportRecord(
        id: id,
        designator: designator,
        ICAOIdentifier: slice.value("locationIndicatorICAO"),
        IATAIdentifier: slice.value("designatorIATA"),
        name: slice.value("name") ?? designator,
        city: slice.value("servedCity", "City", "name"),
        type: slice.value("type").map(AirportType.init) ?? .aerodrome,
        referencePoint: Self.elevatedPoint(slice.descendant("ARP", "ElevatedPoint"))?.location,
        elevation: Self.lengthValue(slice.child("fieldElevation")),
        magneticVariation: ValueParsing.degrees(slice.value("magneticVariation"))
      )
    )
  }

  private func consumeRunway(id: String, slice: XMLNode) {
    guard let designator = slice.value("designator") else {
      report(AIXMRecordError.missingValue(feature: "Runway", id: id, field: "designator"))
      return
    }
    runwayRecords.append(
      RunwayRecord(
        id: id,
        airport: reference(slice.child("associatedAirportHeliport")),
        designator: designator,
        isFixedWing: slice.value("type").map { $0 == "RWY" } ?? true,
        length: Self.lengthValue(slice.child("nominalLength")),
        width: Self.lengthValue(slice.child("nominalWidth")),
        composition: slice.value("surfaceProperties", "SurfaceCharacteristics", "composition")
          .map(SurfaceComposition.init)
      )
    )
  }

  private func consumeDirection(id: String, slice: XMLNode) {
    guard let designator = slice.value("designator") else {
      report(AIXMRecordError.missingValue(feature: "RunwayDirection", id: id, field: "designator"))
      return
    }
    directionRecords.append(
      DirectionRecord(
        id: id,
        runway: reference(slice.child("usedRunway")),
        designator: designator,
        trueBearing: ValueParsing.degrees(slice.value("trueBearing")),
        magneticBearing: ValueParsing.degrees(slice.value("magneticBearing")),
        touchdownZoneElevation: Self.lengthValue(slice.child("elevationTDZ"))
      )
    )
  }

  /// Each declared distance can carry several scheduled values; the longest is the one
  /// available without restriction.
  private func consumePoint(id: String, slice: XMLNode) {
    let distances = slice.children("associatedDeclaredDistance")
      .compactMap { $0.child("RunwayDeclaredDistance") }
      .compactMap { distance -> (String, Measurement<UnitLength>)? in
        let values = distance.children("declaredValue").compactMap {
          Self.lengthValue($0.descendant("RunwayDeclaredDistanceValue", "distance"))
        }
        guard let type = distance.value("type"), let longest = values.max() else { return nil }
        return (type, longest)
      }

    pointRecords.append(
      PointRecord(
        id: id,
        direction: reference(slice.child("onRunway")),
        role: slice.value("role"),
        point: Self.elevatedPoint(slice.descendant("location", "ElevatedPoint")),
        declaredDistances: Dictionary(distances, uniquingKeysWith: { first, _ in first })
      )
    )
  }

  private func consumeNavaid(id: String, slice: XMLNode) {
    navaidRecords.append(
      NavaidRecord(
        id: id,
        equipment: slice.children("navaidEquipment").compactMap {
          reference($0.descendant("NavaidComponent", "theNavaidEquipment"))
        },
        directions: slice.children("runwayDirection").compactMap { reference($0) }
      )
    )
  }

  private func consumeGlidepath(id: String, slice: XMLNode) {
    glidepathsByID[id] = Glidepath(
      angle: ValueParsing.degrees(slice.value("slope")),
      referenceDatumHeight: Self.lengthValue(slice.child("rdh"))
    )
  }

  private func consumeVisualGlideSlope(slice: XMLNode) {
    for direction in slice.children("runwayDirection").compactMap({ reference($0) }) {
      visualGlideSlopeRecords.append(
        (
          direction,
          VisualGlideSlope(
            angle: ValueParsing.degrees(slice.value("slopeAngle")),
            minimumEyeHeightOverThreshold: Self.lengthValue(
              slice.child("minimumEyeHeightOverThreshold")
            )
          )
        )
      )
    }
  }

  private func consumeObstacle(id: String, slice: XMLNode) {
    let parts = slice.children("part")
      .compactMap { $0.child("VerticalStructurePart") }
      .compactMap { obstaclePart($0, obstacleID: id) }
    guard !parts.isEmpty else {
      report(AIXMRecordError.missingValue(feature: "VerticalStructure", id: id, field: "part"))
      return
    }
    obstacles.append(
      Obstacle(
        id: id,
        name: slice.value("name"),
        type: slice.value("type").map(ObstacleType.init),
        isLighted: slice.value("lighted").map { $0 == "YES" },
        parts: parts
      )
    )
  }

  private func obstaclePart(_ part: XMLNode, obstacleID: String) -> ObstaclePart? {
    let height = Self.lengthValue(part.child("verticalExtent"))

    if let point = part.descendant("horizontalProjection_location", "ElevatedPoint") {
      guard let runwayPoint = Self.elevatedPoint(point) else {
        report(
          AIXMRecordError.invalidValue(
            feature: "VerticalStructure",
            id: obstacleID,
            field: "horizontalProjection_location",
            value: point.value("pos") ?? ""
          )
        )
        return nil
      }
      return ObstaclePart(
        geometry: .point(runwayPoint.location),
        topElevation: runwayPoint.elevation,
        height: height
      )
    }

    if let curve = part.descendant("horizontalProjection_linearExtent", "ElevatedCurve") {
      return extentPart(curve, height: height, makeGeometry: ObstacleGeometry.line)
    }
    if let surface = part.descendant("horizontalProjection_surfaceExtent", "ElevatedSurface") {
      return extentPart(surface, height: height, makeGeometry: ObstacleGeometry.surface)
    }
    return nil
  }

  private func extentPart(
    _ extent: XMLNode,
    height: Measurement<UnitLength>?,
    makeGeometry: ([Location]) -> ObstacleGeometry
  ) -> ObstaclePart? {
    let srsName = extent.attributes["srsName"]
    let locations = (extent.descendants(named: "posList") + extent.descendants(named: "pos"))
      .flatMap {
        ValueParsing.positions($0.value, srsName: $0.attributes["srsName"] ?? srsName) ?? []
      }
    guard !locations.isEmpty else { return nil }
    return ObstaclePart(
      geometry: makeGeometry(locations),
      topElevation: Self.lengthValue(extent.child("elevation")),
      height: height
    )
  }

  // MARK: - Linking

  private func linkedDirections() -> [(runwayID: String, direction: RunwayDirection)] {
    let pointsByDirection = Dictionary(
      grouping: pointRecords.compactMap { record -> (String, PointRecord)? in
        resolve(record.direction, from: "RunwayCentrelinePoint", id: record.id).map { ($0, record) }
      },
      by: \.0
    ).mapValues { $0.map(\.1) }
    let glidepaths = glidepathsByDirection()
    let visualGlideSlopes = Dictionary(
      visualGlideSlopeRecords.compactMap { record -> (String, VisualGlideSlope)? in
        resolve(record.direction, from: "VisualGlideSlopeIndicator", id: "").map {
          ($0, record.indicator)
        }
      },
      uniquingKeysWith: { first, _ in first }
    )

    return directionRecords.compactMap { record in
      guard let runwayID = resolve(record.runway, from: "RunwayDirection", id: record.id) else {
        return nil
      }
      return (
        runwayID,
        record.direction(
          points: pointsByDirection[record.id] ?? [],
          glidepath: glidepaths[record.id],
          visualGlideSlope: visualGlideSlopes[record.id]
        )
      )
    }
  }

  private func glidepathsByDirection() -> [String: Glidepath] {
    var glidepaths = [String: Glidepath]()
    for navaid in navaidRecords {
      let glidepath = navaid.equipment.lazy
        .compactMap { self.resolve($0, from: "Navaid", id: navaid.id) }
        .compactMap { self.glidepathsByID[$0] }
        .first
      guard let glidepath else { continue }
      for direction in navaid.directions {
        guard let directionID = resolve(direction, from: "Navaid", id: navaid.id) else { continue }
        glidepaths[directionID] = glidepath
      }
    }
    return glidepaths
  }
}

// MARK: - Intermediate records

/// An unresolved `xlink:href`.
private struct Reference {
  let href: String
}

private struct AirportRecord {
  let id: String
  let designator: String
  let ICAOIdentifier: String?
  let IATAIdentifier: String?
  let name: String
  let city: String?
  let type: AirportType
  let referencePoint: Location?
  let elevation: Measurement<UnitLength>?
  let magneticVariation: Measurement<UnitAngle>?

  func airport(runways: [Runway]) -> Airport {
    Airport(
      id: id,
      designator: designator,
      ICAOIdentifier: ICAOIdentifier,
      IATAIdentifier: IATAIdentifier,
      name: name,
      city: city,
      type: type,
      referencePoint: referencePoint,
      elevation: elevation,
      magneticVariation: magneticVariation,
      runways: runways
    )
  }
}

private struct RunwayRecord {
  let id: String
  let airport: Reference?
  let designator: String
  let isFixedWing: Bool
  let length: Measurement<UnitLength>?
  let width: Measurement<UnitLength>?
  let composition: SurfaceComposition?

  func runway(directions: [RunwayDirection]) -> Runway {
    Runway(
      id: id,
      designator: designator,
      isFixedWing: isFixedWing,
      length: length,
      width: width,
      composition: composition,
      directions: directions.sorted { $0.designator < $1.designator }
    )
  }
}

private struct DirectionRecord {
  /// Centre-line point roles whose declared distances apply to the whole direction, in
  /// order of preference.
  private static let declaredDistanceRoles = ["THR", "DISTHR"]

  let id: String
  let runway: Reference?
  let designator: String
  let trueBearing: Measurement<UnitAngle>?
  let magneticBearing: Measurement<UnitAngle>?
  let touchdownZoneElevation: Measurement<UnitLength>?

  /**
   The declared distances for the full length of the direction.

   Distances on the threshold points come first. Some data sets instead attach them to
   points with no role and no position, alongside the distances for takeoffs from
   intersections. Those never exceed the full-length distances, so the longest of each
   type is taken.
   */
  private static func declaredDistances(_ points: [PointRecord]) -> [String: Measurement<
    UnitLength
  >] {
    let thresholdDistances =
      declaredDistanceRoles
      .flatMap { role in points.filter { $0.role == role } }
      .reduce(into: [String: Measurement<UnitLength>]()) { merged, point in
        merged.merge(point.declaredDistances) { existing, _ in existing }
      }
    let otherDistances = points.filter { !declaredDistanceRoles.contains($0.role ?? "") }
      .reduce(into: [String: Measurement<UnitLength>]()) { merged, point in
        merged.merge(point.declaredDistances) { Swift.max($0, $1) }
      }
    return thresholdDistances.merging(otherDistances) { threshold, _ in threshold }
  }

  func direction(
    points: [PointRecord],
    glidepath: Glidepath?,
    visualGlideSlope: VisualGlideSlope?
  ) -> RunwayDirection {
    func point(_ role: String) -> RunwayPoint? {
      points.first { $0.role == role }?.point
    }
    let distances = Self.declaredDistances(points)

    return RunwayDirection(
      id: id,
      designator: designator,
      trueBearing: trueBearing,
      magneticBearing: magneticBearing,
      threshold: point("THR"),
      displacedThreshold: point("DISTHR"),
      end: point("END"),
      touchdownZoneElevation: touchdownZoneElevation,
      declaredDistances: DeclaredDistances(
        TORA: distances["TORA"],
        TODA: distances["TODA"],
        ASDA: distances["ASDA"],
        LDA: distances["LDA"],
        thresholdDisplacement: distances["DTHR"]
      ),
      glidepath: glidepath,
      visualGlideSlope: visualGlideSlope
    )
  }
}

private struct PointRecord {
  let id: String
  let direction: Reference?
  let role: String?
  let point: RunwayPoint?
  let declaredDistances: [String: Measurement<UnitLength>]
}

private struct NavaidRecord {
  let id: String
  let equipment: [Reference]
  let directions: [Reference]
}
