import Foundation

/// A data set published online for each AIRAC cycle.
enum LiveSource: Hashable, Sendable {

  /// An open flightmaps OFMX snapshot of one region, named by its snapshot folder.
  case openFlightmaps(region: String)

  /// The NATS UK AIP data set.
  case UKAIP

  /// The NATS UK area 1 obstacle data set.
  case UKObstacles

  /// The snapshot folder of each open flightmaps region.
  static let openFlightmapsRegions = [
    "ebbu", "ed", "efin", "ehaa", "ekdk", "epww", "esaa", "fa", "fywh", "lbsr", "ldzo", "lf",
    "lggg", "lhcc", "li", "ljla", "lkaa", "lmmm", "lovv", "lrbb", "lsas", "lzbb"
  ]

  static let all = openFlightmapsRegions.map(Self.openFlightmaps) + [.UKAIP, .UKObstacles]

  /// The page that links each cycle's NATS digital data sets.
  static let NATSDataSetsPage = URL(
    string: "https://nats-uk.ead-it.com/cms-nats/opencms/en/Publications/digital-datasets/"
  )!

  private static let openFlightmapsSnapshots = URL(
    string: "https://snapshots.openflightmaps.org/live/"
  )!

  /// The length of the prefix open flightmaps names a region's snapshot file with.
  private static let openFlightmapsFilePrefixLength = 2

  /// The name the source is reported under. It stays the same from cycle to cycle.
  var name: String {
    switch self {
      case .openFlightmaps(let region): "ofmx/\(region)"
      case .UKAIP: "uk/aip"
      case .UKObstacles: "uk/obstacles"
    }
  }

  /// Whether the source is selected by a `--source` filter: its name, or the part of its name
  /// before the slash.
  func matches(_ filter: String) -> Bool {
    name == filter || name.hasPrefix("\(filter)/")
  }

  /// The name the source's data set is saved under for the given cycle.
  func filename(cycle: AIRACCycle) -> String {
    switch self {
      case .openFlightmaps(let region): "ofmx_\(region).ofmx"
      case .UKAIP: "EG_AIP_DS_FULL_\(cycle.compactEffectiveDate).xml"
      case .UKObstacles: "EG_OBS_DS_AREA1_FULL_\(cycle.compactEffectiveDate).xml"
    }
  }

  /// Where the source's data set is downloaded from. NATS archives are found by name on
  /// ``NATSDataSetsPage``; open flightmaps snapshots are at a fixed path.
  func location(cycle: AIRACCycle) -> Location {
    switch self {
      case .openFlightmaps(let region):
        let file = "ofmx_\(region.prefix(Self.openFlightmapsFilePrefixLength)).ofmx"
        return .file(
          Self.openFlightmapsSnapshots.appending(
            path: "\(cycle.identifier)/ofmx/\(region)/latest/isolated/\(file)"
          )
        )
      case .UKAIP:
        return .linkedArchive(
          name: "EG_AIP_DS_\(cycle.compactEffectiveDate)_XML.zip",
          entry: filename(cycle: cycle)
        )
      case .UKObstacles:
        return .linkedArchive(
          name: "EG_OBS_DS_AREA1_FULL_\(cycle.compactEffectiveDate)_XML.zip",
          entry: filename(cycle: cycle)
        )
    }
  }

  /// Where a data set is published.
  enum Location {

    /// The data set itself, at a URL.
    case file(URL)

    /// An archive linked from ``LiveSource/NATSDataSetsPage`` under the given file name,
    /// holding the data set as the given entry.
    case linkedArchive(name: String, entry: String)
  }
}
