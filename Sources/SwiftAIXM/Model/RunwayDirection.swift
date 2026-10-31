public import Foundation

/// One direction of use of a ``Runway``, identified by the designator painted at its
/// approach end.
public struct RunwayDirection: Sendable, Codable, Hashable, Identifiable {

  /// The record's identifier in its data set.
  public let id: String

  /// The direction's designator, such as `"08"` or `"27L"`.
  public let designator: String

  /// The runway's true bearing in this direction.
  public let trueBearing: Measurement<UnitAngle>?

  /// The runway's magnetic bearing in this direction.
  public let magneticBearing: Measurement<UnitAngle>?

  /// The threshold, with its elevation: the start of the runway available for landing when it
  /// isn't displaced.
  public let threshold: Location?

  /// The displaced threshold, with its elevation, if the threshold is displaced.
  public let displacedThreshold: Location?

  /// The far end of the runway in this direction.
  public let end: Location?

  /// The elevation of the touchdown zone.
  public let touchdownZoneElevation: Measurement<UnitLength>?

  /// The declared distances for this direction.
  public let declaredDistances: DeclaredDistances

  /// The ILS glide path serving this direction.
  public let glidepath: Glidepath?

  /// The visual approach slope indicator (PAPI, VASI) serving this direction.
  public let visualGlideSlope: VisualGlideSlope?

  /// Creates a runway direction record.
  public init(
    id: String,
    designator: String,
    trueBearing: Measurement<UnitAngle>?,
    magneticBearing: Measurement<UnitAngle>?,
    threshold: Location?,
    displacedThreshold: Location?,
    end: Location?,
    touchdownZoneElevation: Measurement<UnitLength>?,
    declaredDistances: DeclaredDistances,
    glidepath: Glidepath?,
    visualGlideSlope: VisualGlideSlope?
  ) {
    self.id = id
    self.designator = designator
    self.trueBearing = trueBearing
    self.magneticBearing = magneticBearing
    self.threshold = threshold
    self.displacedThreshold = displacedThreshold
    self.end = end
    self.touchdownZoneElevation = touchdownZoneElevation
    self.declaredDistances = declaredDistances
    self.glidepath = glidepath
    self.visualGlideSlope = visualGlideSlope
  }
}

/// The distances declared available for takeoff and landing in one runway direction.
public struct DeclaredDistances: Sendable, Codable, Hashable {

  /// No distances declared.
  public static let none = Self(
    TORA: nil,
    TODA: nil,
    ASDA: nil,
    LDA: nil,
    thresholdDisplacement: nil
  )

  /// Takeoff run available.
  public let TORA: Measurement<UnitLength>?

  /// Takeoff distance available.
  public let TODA: Measurement<UnitLength>?

  /// Accelerate-stop distance available.
  public let ASDA: Measurement<UnitLength>?

  /// Landing distance available.
  public let LDA: Measurement<UnitLength>?

  /// The distance the threshold is displaced from the start of the runway.
  public let thresholdDisplacement: Measurement<UnitLength>?

  /// Creates a set of declared distances.
  public init(
    TORA: Measurement<UnitLength>?,
    TODA: Measurement<UnitLength>?,
    ASDA: Measurement<UnitLength>?,
    LDA: Measurement<UnitLength>?,
    thresholdDisplacement: Measurement<UnitLength>?
  ) {
    self.TORA = TORA
    self.TODA = TODA
    self.ASDA = ASDA
    self.LDA = LDA
    self.thresholdDisplacement = thresholdDisplacement
  }
}

/// The glide path component of an instrument landing system.
public struct Glidepath: Sendable, Codable, Hashable {

  /// The glide path angle.
  public let angle: Measurement<UnitAngle>?

  /// The height of the glide path over the threshold (the ILS reference datum height).
  public let referenceDatumHeight: Measurement<UnitLength>?

  /// Creates a glide path record.
  public init(angle: Measurement<UnitAngle>?, referenceDatumHeight: Measurement<UnitLength>?) {
    self.angle = angle
    self.referenceDatumHeight = referenceDatumHeight
  }
}

/// A visual approach slope indicator, such as a PAPI.
public struct VisualGlideSlope: Sendable, Codable, Hashable {

  /// The approach slope angle the indicator shows.
  public let angle: Measurement<UnitAngle>?

  /// The minimum eye height over the threshold on the indicated slope.
  public let minimumEyeHeightOverThreshold: Measurement<UnitLength>?

  /// Creates a visual approach slope indicator record.
  public init(
    angle: Measurement<UnitAngle>?,
    minimumEyeHeightOverThreshold: Measurement<UnitLength>?
  ) {
    self.angle = angle
    self.minimumEyeHeightOverThreshold = minimumEyeHeightOverThreshold
  }
}
