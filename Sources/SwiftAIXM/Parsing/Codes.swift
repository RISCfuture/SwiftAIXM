/// AIXM 5.1 runway centre-line point roles.
enum RunwayPointRole: String {
  case start = "START"
  case threshold = "THR"
  case displacedThreshold = "DISTHR"
  case touchdownZone = "TDZ"
  case middle = "MID"
  case end = "END"
  case startOfRun = "START_RUN"
  case landAndHoldShort = "LAHSO"
  case abeamGlideslope = "ABEAM_GLIDESLOPE"
  case abeamPrecisionApproachRadar = "ABEAM_PAR"
  case abeamElevation = "ABEAM_ELEVATION"
  case abeamTouchdownReflector = "ABEAM_TDR"
  case abeamRunwayEndReflector = "ABEAM_RER"
  case other = "OTHER"

  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self(otherCode: code) else { return nil }
    self = value
  }
}

/// Declared distance types, in AIXM 5.1 and OFMX.
enum DeclaredDistanceType: String {
  case LDA
  case TORA
  case TODA
  case ASDA
  case thresholdDisplacement = "DTHR"
  case helicopterTODA = "TODAH"
  case helicopterRejectedTODA = "RTODAH"
  case helicopterLDA = "LDAH"
  case other = "OTHER"

  /// open flightmaps' code for the threshold displacement.
  private static let OFMXCodes: [String: Self] = ["DPLM": .thresholdDisplacement]

  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self.OFMXCodes[code] ?? Self(otherCode: code) else {
      return nil
    }
    self = value
  }
}

/// AIXM 5.1 runway types.
enum RunwayType: String {
  case runway = "RWY"
  case finalApproachAndTakeoffArea = "FATO"
  case other = "OTHER"

  init?(code: String) {
    guard let value = Self(rawValue: code) ?? Self(otherCode: code) else { return nil }
    self = value
  }
}

extension RunwayPointRole: OtherCodeRepresentable {}
extension DeclaredDistanceType: OtherCodeRepresentable {}
extension RunwayType: OtherCodeRepresentable {}
