/// Code lists whose `OTHER` value AIXM also allows to carry text, as in `OTHER:MAST`.
protocol OtherCodeRepresentable: RawRepresentable where RawValue == String {
  static var other: Self { get }
}

extension OtherCodeRepresentable {
  /// ``other`` for `OTHER` or `OTHER:<text>`, which AIXM allows in every code list.
  init?(otherCode code: String) {
    guard code == "OTHER" || code.hasPrefix("OTHER:") else { return nil }
    self = .other
  }
}

extension AirportType: OtherCodeRepresentable {}
extension SurfaceComposition: OtherCodeRepresentable {}
extension ObstacleType: OtherCodeRepresentable {}
