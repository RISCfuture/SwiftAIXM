/// Writes small OFMX snapshots, so a test can state exactly the features it reads.
enum OFMXDocument {

  /// A snapshot holding the given features.
  static func snapshot(_ features: String...) -> String {
    snapshot(features: features)
  }

  /// A snapshot holding the given features.
  static func snapshot(features: [String]) -> String {
    """
    <?xml version="1.0" encoding="utf-8"?>
    <OFMX-Snapshot version="0.1" effective="2026-10-23T20:15:34Z">
    \(features.joined(separator: "\n"))
    </OFMX-Snapshot>
    """
  }

  /// An aerodrome's `AhpUid`, its natural key.
  static func airportUID(_ code: String?) -> String {
    #"<AhpUid mid="ahp-\#(code ?? "")">\#(code.map { "<codeId>\($0)</codeId>" } ?? "")</AhpUid>"#
  }

  /// A runway's `RwyUid`: its aerodrome and its designator.
  static func runwayUID(_ airport: String, _ designator: String?) -> String {
    """
    <RwyUid \
    mid="rwy-\(airport)-\(designator ?? "")">\(airportUID(airport))\(designator.map { "<txtDesig>\($0)</txtDesig>" } ?? "")</RwyUid>
    """
  }

  /// A runway direction's `RdnUid`: its runway and its designator.
  static func directionUID(_ airport: String, _ runway: String, _ designator: String?) -> String {
    """
    <RdnUid \
    mid="rdn-\(airport)-\(designator ?? "")">\(runwayUID(airport, runway))\(designator.map { "<txtDesig>\($0)</txtDesig>" } ?? "")</RdnUid>
    """
  }

  /// An aerodrome.
  static func airport(_ code: String?, _ properties: String...) -> String {
    "<Ahp>\(airportUID(code))\(properties.joined())</Ahp>"
  }

  /// A runway.
  static func runway(_ airport: String, _ designator: String?, _ properties: String...) -> String {
    "<Rwy>\(runwayUID(airport, designator))\(properties.joined())</Rwy>"
  }

  /// A runway direction.
  static func direction(
    _ airport: String,
    _ runway: String,
    _ designator: String?,
    _ properties: String...
  ) -> String {
    "<Rdn>\(directionUID(airport, runway, designator))\(properties.joined())</Rdn>"
  }

  /// A declared distance.
  static func declaredDistance(
    _ airport: String,
    _ runway: String,
    _ direction: String,
    type: String,
    period: String = "A",
    value: String,
    unit: String = "M"
  ) -> String {
    """
    <Rdd><RddUid>\(directionUID(airport, runway, direction))<codeType>\(type)</codeType><codeDayPeriod>\(period)</codeDayPeriod></RddUid><valDist>\(value)</valDist><uomDist>\(unit)</uomDist></Rdd>
    """
  }

  /// An obstacle at the given position.
  static func obstacle(
    mid: String,
    latitude: String?,
    longitude: String?,
    _ properties: String...
  ) -> String {
    """
    <Obs><ObsUid \
    mid="\(mid)">\(latitude.map { "<geoLat>\($0)</geoLat>" } ?? "")\(longitude.map { "<geoLong>\($0)</geoLong>" } ?? "")</ObsUid>\(properties.joined())</Obs>
    """
  }

  /// An element with a text value.
  static func value(_ element: String, _ text: String) -> String {
    "<\(element)>\(text)</\(element)>"
  }
}
