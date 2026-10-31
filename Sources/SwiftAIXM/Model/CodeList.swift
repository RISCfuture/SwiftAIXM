/**
 A value from an AIXM code list.

 Every AIXM code list is open: besides its enumerated values, a data set may carry
 `OTHER` or `OTHER:<text>`. Conforming types therefore wrap the code as written and
 offer the enumerated values as static members, so no coded value is lost and
 known values can still be matched with `switch`.
 */
public protocol CodeList: RawRepresentable, Sendable, Codable, Hashable
where RawValue == String {

  /// Creates a value from its code as written in the data set.
  init(rawValue: String)
}
