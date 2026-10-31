/// Writes small AIXM 5.1 messages, so a test can state exactly the features it reads.
enum AIXM51Document {

  /// A message holding the given features.
  static func message(_ features: String...) -> String {
    message(features: features)
  }

  /// A message holding the given features.
  static func message(features: [String]) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <message:AIXMBasicMessage xmlns:aixm="http://www.aixm.aero/schema/5.1"
        xmlns:gml="http://www.opengis.net/gml/3.2"
        xmlns:message="http://www.aixm.aero/schema/5.1/message"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        gml:id="message">
    \(features.map { "<message:hasMember>\($0)</message:hasMember>" }.joined(separator: "\n"))
    </message:AIXMBasicMessage>
    """
  }

  /// A feature with one `BASELINE` time slice, valid since 2020, holding the given properties.
  static func feature(
    _ name: String,
    uuid: String?,
    localID: String? = nil,
    _ properties: String...
  ) -> String {
    feature(name, uuid: uuid, localID: localID, slices: [slice(name, properties: properties)])
  }

  /// A feature with the given time slices.
  static func feature(
    _ name: String,
    uuid: String?,
    localID: String? = nil,
    slices: [String]
  ) -> String {
    let identifier = uuid.map { #"<gml:identifier codeSpace="urn:uuid:">\#($0)</gml:identifier>"# }
    return """
      <aixm:\(name)\(localID.map { #" gml:id="\#($0)""# } ?? "")>
        \(identifier ?? "")
        \(slices.map { "<aixm:timeSlice>\($0)</aixm:timeSlice>" }.joined())
      </aixm:\(name)>
      """
  }

  /// A time slice of the named feature. Without either end of its valid time, the slice has no
  /// valid time at all.
  static func slice(
    _ feature: String,
    interpretation: String = "BASELINE",
    sequence: Int = 1,
    correction: Int = 0,
    validFrom: String? = "2020-01-01T00:00:00Z",
    validUntil: String? = nil,
    lifetimeEnd: String? = nil,
    properties: [String]
  ) -> String {
    let validTime =
      validFrom == nil && validUntil == nil
      ? ""
      : """
      <gml:validTime><gml:TimePeriod>
        \(validFrom.map { "<gml:beginPosition>\($0)</gml:beginPosition>" } ?? "")
        \
      \(validUntil.map { "<gml:endPosition>\($0)</gml:endPosition>" }
            ?? #"<gml:endPosition indeterminatePosition="unknown"/>"#)
      </gml:TimePeriod></gml:validTime>
      """
    let lifetime = lifetimeEnd.map {
      """
      <aixm:featureLifetime><gml:TimePeriod>
        <gml:beginPosition>2020-01-01T00:00:00Z</gml:beginPosition>
        <gml:endPosition>\($0)</gml:endPosition>
      </gml:TimePeriod></aixm:featureLifetime>
      """
    }
    return """
      <aixm:\(feature)TimeSlice>
        \(validTime)
        <aixm:interpretation>\(interpretation)</aixm:interpretation>
        <aixm:sequenceNumber>\(sequence)</aixm:sequenceNumber>
        <aixm:correctionNumber>\(correction)</aixm:correctionNumber>
        \(lifetime ?? "")
        \(properties.joined(separator: "\n"))
      </aixm:\(feature)TimeSlice>
      """
  }

  /// A property with a text value and, optionally, a unit of measure.
  static func value(_ property: String, _ text: String, uom: String? = nil) -> String {
    "<aixm:\(property)\(uom.map { #" uom="\#($0)""# } ?? "")>\(text)</aixm:\(property)>"
  }

  /// A property referring to another feature.
  static func reference(_ property: String, _ href: String) -> String {
    #"<aixm:\#(property) xlink:href="\#(href)"/>"#
  }

  /// A property holding an `aixm:ElevatedPoint`.
  static func elevatedPoint(
    _ property: String,
    _ position: String,
    srsName: String = "urn:ogc:def:crs:EPSG::4326",
    elevation: String? = nil
  ) -> String {
    """
    <aixm:\(property)><aixm:ElevatedPoint srsName="\(srsName)">
      <gml:pos>\(position)</gml:pos>
      \(elevation.map { #"<aixm:elevation uom="FT">\#($0)</aixm:elevation>"# } ?? "")
    </aixm:ElevatedPoint></aixm:\(property)>
    """
  }

  /// A runway centre-line point's declared distance, with each of its scheduled values.
  static func declaredDistance(_ type: String, meters values: Double...) -> String {
    let declaredValues = values.map { value in
      """
      <aixm:declaredValue><aixm:RunwayDeclaredDistanceValue>
        <aixm:distance uom="M">\(value)</aixm:distance>
      </aixm:RunwayDeclaredDistanceValue></aixm:declaredValue>
      """
    }
    return """
      <aixm:associatedDeclaredDistance><aixm:RunwayDeclaredDistance>
        <aixm:type>\(type)</aixm:type>
        \(declaredValues.joined())
      </aixm:RunwayDeclaredDistance></aixm:associatedDeclaredDistance>
      """
  }
}

// MARK: - Aerodrome features

extension AIXM51Document {

  /// An `AirportHeliport`, identified by `uuid` and locally by `gml:id` `ahp-<uuid>`.
  static func airport(uuid: String = "ahp", designator: String? = "XXAA", _ properties: String...)
    -> String
  {
    feature(
      "AirportHeliport",
      uuid: uuid,
      localID: "ahp-\(uuid)",
      slices: [
        slice(
          "AirportHeliport",
          properties: (designator.map { [value("designator", $0)] } ?? []) + properties
        )
      ]
    )
  }

  /// A `Runway` of the aerodrome `airport` refers to.
  static func runway(
    uuid: String = "rwy",
    airport: String? = "urn:uuid:ahp",
    designator: String? = "09/27",
    _ properties: String...
  ) -> String {
    feature(
      "Runway",
      uuid: uuid,
      slices: [
        slice(
          "Runway",
          properties: (designator.map { [value("designator", $0)] } ?? [])
            + (airport.map { [reference("associatedAirportHeliport", $0)] } ?? []) + properties
        )
      ]
    )
  }

  /// A `RunwayDirection` of the runway `runway` refers to.
  static func direction(
    uuid: String,
    runway: String = "urn:uuid:rwy",
    designator: String?,
    _ properties: String...
  ) -> String {
    feature(
      "RunwayDirection",
      uuid: uuid,
      slices: [
        slice(
          "RunwayDirection",
          properties: (designator.map { [value("designator", $0)] } ?? [])
            + [reference("usedRunway", runway)] + properties
        )
      ]
    )
  }

  /// A `RunwayCentrelinePoint` on the runway direction `direction` refers to.
  static func centrelinePoint(
    uuid: String,
    direction: String,
    role: String?,
    _ properties: String...
  ) -> String {
    centrelinePoint(uuid: uuid, direction: direction, role: role, properties: properties)
  }

  /// A `RunwayCentrelinePoint` on the runway direction `direction` refers to.
  static func centrelinePoint(
    uuid: String,
    direction: String,
    role: String?,
    properties: [String]
  ) -> String {
    feature(
      "RunwayCentrelinePoint",
      uuid: uuid,
      slices: [
        slice(
          "RunwayCentrelinePoint",
          properties: (role.map { [value("role", $0)] } ?? [])
            + [reference("onRunway", direction)] + properties
        )
      ]
    )
  }
}
