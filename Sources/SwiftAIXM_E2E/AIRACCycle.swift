import ArgumentParser
import Foundation

/// A 28-day AIRAC cycle, identified as ICAO does by the last two digits of its year and its
/// number within that year, such as `2611`.
struct AIRACCycle: Comparable, CustomStringConvertible {

  /// Cycle 2001 took effect on 2 January 2020; every cycle since follows 28 days after the last.
  private static let datum = Date(timeIntervalSince1970: 1_577_923_200)
  private static let daysPerCycle = 28
  private static let secondsPerDay = 86_400
  private static let secondsPerCycle = TimeInterval(daysPerCycle * secondsPerDay)
  private static let identifierLength = 4
  private static let centuryStart = 2000
  private static let yearDigits = 100

  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  /// The cycle that is in effect now.
  static var effective: Self { Self(containing: .now) }

  /// Cycles since cycle 2001.
  private let index: Int

  /// The date the cycle takes effect, at 00:00 UTC.
  var effectiveDate: Date { Self.datum.addingTimeInterval(Double(index) * Self.secondsPerCycle) }

  /// The four-digit identifier, such as `2611`.
  var identifier: String {
    let year = Self.calendar.component(.year, from: effectiveDate)
    let number = index - Self.firstIndex(ofYear: year) + 1
    return Self.twoDigits(year % Self.yearDigits) + Self.twoDigits(number)
  }

  /// The effective date as `YYYYMMDD`, as NATS writes it in file names.
  var compactEffectiveDate: String {
    effectiveDate.formatted(.iso8601.year().month().day().dateSeparator(.omitted))
  }

  var next: Self { Self(index: index + 1) }

  var description: String { identifier }

  private init(index: Int) {
    self.index = index
  }

  /// The cycle in effect on the given date.
  init(containing date: Date) {
    index = Int((date.timeIntervalSince(Self.datum) / Self.secondsPerCycle).rounded(.down))
  }

  /// The cycle with the given four-digit identifier, or `nil` if no cycle has it.
  init?(identifier: String) {
    guard identifier.count == Self.identifierLength, identifier.allSatisfy(\.isASCII),
      let yearPart = Int(identifier.prefix(2)), let number = Int(identifier.suffix(2)), number >= 1
    else { return nil }

    let year = Self.centuryStart + yearPart
    let cycle = Self(index: Self.firstIndex(ofYear: year) + number - 1)
    guard Self.calendar.component(.year, from: cycle.effectiveDate) == year else { return nil }
    self = cycle
  }

  /// The index of the first cycle to take effect in the given year.
  private static func firstIndex(ofYear year: Int) -> Int {
    guard let newYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
      preconditionFailure("Every year has a first of January")
    }
    let containing = Self(containing: newYear)
    return containing.effectiveDate < newYear ? containing.index + 1 : containing.index
  }

  private static func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : String(value)
  }

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.index < rhs.index }
}

extension AIRACCycle: ExpressibleByArgument {
  init?(argument: String) {
    switch argument.lowercased() {
      case "effective": self = .effective
      case "next": self = Self.effective.next
      default: self.init(identifier: argument)
    }
  }
}
