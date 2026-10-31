public import Foundation

/// A runway, with one ``RunwayDirection`` for each end it can be used from.
public struct Runway: Sendable, Codable, Hashable, Identifiable {

  /// The record's identifier in its data set.
  public let id: String

  /// The runway's designator, such as `"08/26"`.
  public let designator: String

  /// Whether this is a runway for aeroplanes, as opposed to a helicopter final approach
  /// and takeoff area.
  public let isFixedWing: Bool

  /// The runway's published length.
  public let length: Measurement<UnitLength>?

  /// The runway's published width.
  public let width: Measurement<UnitLength>?

  /// The runway's surface material.
  public let composition: SurfaceComposition?

  /// The directions the runway can be used in.
  public let directions: [RunwayDirection]

  /// Creates a runway record.
  public init(
    id: String,
    designator: String,
    isFixedWing: Bool,
    length: Measurement<UnitLength>?,
    width: Measurement<UnitLength>?,
    composition: SurfaceComposition?,
    directions: [RunwayDirection]
  ) {
    self.id = id
    self.designator = designator
    self.isFixedWing = isFixedWing
    self.length = length
    self.width = width
    self.composition = composition
    self.directions = directions
  }
}
