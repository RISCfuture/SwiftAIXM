import Foundation

/// Parses the units, numbers, and coordinates the data sets are written in.
enum ValueParsing {
  private static let lengthUnits: [String: UnitLength] = [
    "M": .meters,
    "FT": .feet,
    "KM": .kilometers,
    "NM": .nauticalMiles,
    "MI": .miles,
    "CM": .centimeters
  ]

  /// The longest integer part, in digits, of a coordinate written in decimal degrees.
  private static let maxDecimalDegreeDigits = 3

  /// The longest integer part, in digits, of a coordinate written in degrees and minutes.
  private static let maxDegreeMinuteDigits = 5

  /// The longest integer part, in digits, of a coordinate written in degrees, minutes, and
  /// seconds.
  private static let maxDegreeMinuteSecondDigits = 7

  private static let minutesPerDegree = 60.0
  private static let secondsPerDegree = 3600.0

  /// The ISO 8601 forms GML time positions are written in, most specific first. Each later
  /// form also reads a prefix of the earlier ones, so the order matters.
  private static let dateFormats: [Date.ISO8601FormatStyle] = [
    .iso8601,
    .init(includingFractionalSeconds: true),
    zonelessTime(includingFractionalSeconds: true),
    zonelessTime(includingFractionalSeconds: false),
    .init(timeZone: .gmt).year().month().day()
  ]

  /// A date and time with no time zone, read as UTC.
  private static func zonelessTime(includingFractionalSeconds: Bool) -> Date.ISO8601FormatStyle {
    Date.ISO8601FormatStyle(timeZone: .gmt)
      .year()
      .month()
      .day()
      .dateTimeSeparator(.standard)
      .time(includingFractionalSeconds: includingFractionalSeconds)
  }

  /// A length in the given AIXM unit of measure.
  static func length(_ text: String?, unit: String?) -> Measurement<UnitLength>? {
    guard let text, let value = Double(text), let unit, let lengthUnit = lengthUnits[unit] else {
      return nil
    }
    return Measurement(value: value, unit: lengthUnit)
  }

  /// An angle in degrees.
  static func degrees(_ text: String?) -> Measurement<UnitAngle>? {
    guard let text, let value = Double(text) else { return nil }
    return Measurement(value: value, unit: .degrees)
  }

  /**
   A `gml:pos` or `gml:posList` value, as a list of positions.

   GML gives axis order by coordinate reference system: `EPSG:4326` lists latitude
   first, while `OGC:1.3:CRS84` lists longitude first.
   */
  static func positions(_ text: String?, srsName: String?) -> [Location]? {
    guard let text else { return nil }
    let tokens = text.split(whereSeparator: \.isWhitespace)
    let numbers = tokens.compactMap { Double($0) }
    guard !numbers.isEmpty, numbers.count == tokens.count, numbers.count.isMultiple(of: 2) else {
      return nil
    }

    let longitudeFirst = srsName?.contains("CRS84") == true
    return stride(from: 0, to: numbers.count, by: 2).map { index in
      let (first, second) = (numbers[index], numbers[index + 1])
      return longitudeFirst
        ? Location(latitudeDeg: second, longitudeDeg: first)
        : Location(latitudeDeg: first, longitudeDeg: second)
    }
  }

  /**
   An AIXM 4.5 latitude or longitude, such as `47.26027778N`, `4715.5N`, or
   `0112038.00E`.

   The hemisphere letter follows the value. The length of the integer part tells the
   notation apart: up to three digits is decimal degrees, four or five is degrees and
   minutes, and six or seven is degrees, minutes, and seconds.
   */
  static func hemisphereCoordinate(_ text: String?) -> Double? {
    guard let text, let hemisphere = text.last, "NSEW".contains(hemisphere) else { return nil }
    let number = text.dropLast()
    let integerPart = number.prefix { $0 != "." }
    let fraction = number.dropFirst(integerPart.count)
    guard let magnitude = magnitude(integerPart: integerPart, fraction: fraction) else {
      return nil
    }
    return "SW".contains(hemisphere) ? -magnitude : magnitude
  }

  private static func magnitude(integerPart: Substring, fraction: Substring) -> Double? {
    guard integerPart.allSatisfy(\.isNumber), !integerPart.isEmpty,
      integerPart.count <= maxDegreeMinuteSecondDigits
    else { return nil }

    if integerPart.count <= maxDecimalDegreeDigits {
      return Double(integerPart + fraction)
    }

    let secondsDigits = integerPart.count > maxDegreeMinuteDigits ? 2 : 0
    let degreeDigits = integerPart.count - 2 - secondsDigits
    let degrees = Double(integerPart.prefix(degreeDigits))
    let minutesText = integerPart.dropFirst(degreeDigits).prefix(2)
    let lastText = integerPart.dropFirst(degreeDigits + 2) + fraction

    guard let degrees else { return nil }
    if secondsDigits == 0 {
      guard let minutes = Double(minutesText + fraction) else { return nil }
      return degrees + minutes / minutesPerDegree
    }
    guard let minutes = Double(minutesText), let seconds = Double(lastText) else { return nil }
    return degrees + minutes / minutesPerDegree + seconds / secondsPerDegree
  }

  /**
   A GML time position, with or without fractional seconds.

   A time written without a time zone, or a date written without a time, is read as UTC.
   */
  static func date(_ text: String?) -> Date? {
    guard let text else { return nil }
    return dateFormats.lazy.compactMap { try? Date(text, strategy: $0) }.first
  }
}
