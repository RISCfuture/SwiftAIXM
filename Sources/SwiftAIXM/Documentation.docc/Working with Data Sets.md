# Working with Data Sets

How SwiftAIXM reads each format, resolves time and references, and reports what it can't
read.

## Overview

An ``AIXMDataset`` reads one document. The document's root element decides how it is read,
and ``AIXMDataset/format`` records which way that was:

| Root element | Format | Published by |
|---|---|---|
| `AIXMBasicMessage` | ``AIXMDataset/Format/AIXM51`` | NATS (UK AIP and obstacle data sets), Austro Control and the Swiss FOCA (obstacle data sets), and other ICAO data set providers |
| `OFMX-Snapshot` | ``AIXMDataset/Format/OFMX`` | open flightmaps, one snapshot per region |

Documents are read as a stream: each feature is captured on its own, turned into an
intermediate record, and discarded, and the records are linked into ``Airport``s and
``Obstacle``s once the document has been read. Only the features SwiftAIXM models are kept,
so memory use follows the number of aerodromes and obstacles rather than the size of the
file.

### AIXM 5.1 and OFMX

The two formats describe the same things differently.

**AIXM 5.1** is made of features that refer to each other by `xlink:href`. SwiftAIXM reads
`AirportHeliport`, `Runway`, `RunwayDirection`, `RunwayCentrelinePoint`, `Navaid`,
`Glidepath`, `VisualGlideSlopeIndicator`, and `VerticalStructure` features. A reference is
either a `urn:uuid:` identifier or a local `#` reference to another feature's `gml:id`, and
references are resolved after the whole message has been read, so features may appear in any
order. Record identifiers (``Airport/id``, ``Runway/id``, and so on) are the features'
`gml:identifier` UUIDs.

**OFMX** is AIXM 4.5 as open flightmaps writes it. Features identify each other by natural
keys nested in their `…Uid` elements: an aerodrome (`Ahp`) by its code, a runway (`Rwy`) by
its aerodrome and designator, a runway direction (`Rdn`) by its runway and designator, and a
declared distance (`Rdd`) by its runway direction, type, and day period. Obstacles are `Obs`
features. Record identifiers are the `mid` attributes of the `…Uid` elements where present.

Some properties exist in only one format:

- OFMX gives one position per runway direction, so ``RunwayDirection/end`` is always `nil`,
  and it carries no glide paths, so ``RunwayDirection/glidepath`` is always `nil`.
- OFMX runways are all runways for aeroplanes; helicopter final approach and takeoff areas
  are separate features SwiftAIXM doesn't read. In AIXM 5.1 they are `Runway` features of
  type `FATO`, read with ``Runway/isFixedWing`` set to `false`.
- AIXM 5.1 joins a glide path to a runway direction through the `Navaid` (an ILS) that has
  both the `Glidepath` as equipment and the `RunwayDirection` it serves.

### Time Slices and the Effective Date

Every AIXM 5.1 feature carries one or more time slices, each describing the feature over a
period. The `effectiveDate` you pass when reading a data set picks one slice per feature:

- Only `BASELINE` and `SNAPSHOT` slices are considered. `TEMPDELTA` and `PERMDELTA` slices
  describe changes relative to a baseline and are ignored.
- A slice is in effect when its valid time began on or before the effective date and ends
  after it. A slice with no valid time is always in effect.
- When several slices are in effect, the one with the highest sequence number wins, then the
  one with the highest correction number.
- A feature whose lifetime ended on or before the effective date is dropped.

Time positions are ISO 8601. One written without a time zone, or a date written without a
time, is read as UTC.

OFMX snapshots have no time slices: a snapshot is the data in effect when it was made, and
the effective date has no bearing on how it is read.

### Thresholds

AIXM 5.1 places runway positions on `RunwayCentrelinePoint` features, distinguished by role:
the point with role `THR` becomes ``RunwayDirection/threshold``, `DISTHR` becomes
``RunwayDirection/displacedThreshold``, and `END` becomes ``RunwayDirection/end``. Each
carries its own elevation.

OFMX gives a single position for each runway direction. It is the displaced threshold when
the threshold is displaced — when the direction has a `DPLM` declared distance greater than
zero — and the threshold otherwise, so the position lands in
``RunwayDirection/displacedThreshold`` or ``RunwayDirection/threshold`` accordingly, and the
other is `nil`. OFMX runway direction positions carry no elevation.

### Declared Distances

``RunwayDirection/declaredDistances`` holds the distances available for the full length of
the direction.

In AIXM 5.1, declared distances are attached to centre-line points, and a data set may attach
them to several points of one direction. SwiftAIXM merges them per distance type:

1. Distances on the threshold point come first, then those on the displaced threshold point.
2. A distance type neither has is taken from the other points — usually points with no role,
   which some data sets use for every declared distance, including those for takeoffs from
   intersections. A distance can also list several scheduled values. Neither an intersection
   distance nor a restricted schedule exceeds the full-length distance, so the longest value
   across those points and their scheduled values is the one reported.

In OFMX, each `Rdd` feature gives one distance for one day period. All-day (`A`) distances
are preferred over daytime (`D`) distances; night-time (`N`) and `OTHER` distances are
ignored. The `DPLM` distance is the threshold displacement,
``DeclaredDistances/thresholdDisplacement``.

### Obstacles

An ``Obstacle`` is made of ``ObstaclePart``s: a single structure has one part, while a group
of structures or a line strung between towers has several. Each part has a footprint, its
``ObstaclePart/geometry``:

- ``ObstacleGeometry/point(_:)`` for a mast, building, or tree.
- ``ObstacleGeometry/line(_:)`` for a cable or a power line, one part per span.
- ``ObstacleGeometry/surface(_:)`` for an area such as a wind farm or a stand of trees, with
  the polygon's boundary.

GML lists coordinates in the axis order of the coordinate reference system named by
`srsName`. `EPSG:4326` lists latitude first, while `OGC:1.3:CRS84`, which the Swiss FOCA data
set uses, lists longitude first. SwiftAIXM reads each in its own order, so every ``Location``
holds latitude and longitude the right way round whichever the data set uses.

A part has two vertical measures. ``ObstaclePart/topElevation`` is the elevation of its
highest point above mean sea level — the elevation of the AIXM 5.1 point, curve, or surface,
or the OFMX `valElev` — and is what obstacle clearance is computed against.
``ObstaclePart/height`` is the part's height above the ground beneath it. Positions in
``ObstaclePart/geometry`` carry no elevation of their own.

A part whose footprint can't be read is left out; an obstacle with no part left is reported
and skipped.

### Errors

Problems come in two kinds.

A document that can't be read at all throws ``AIXMError``: the file doesn't exist
(``AIXMError/fileNotFound(_:)``), the XML is malformed or ends early
(``AIXMError/malformedXML(reason:line:)``), or the root element is neither an AIXM 5.1
message nor an OFMX snapshot (``AIXMError/unrecognizedFormat(rootElement:)``).

A problem with a single record is passed to the error callback as an ``AIXMRecordError``,
and reading continues:

- ``AIXMRecordError/missingValue(feature:id:field:)``: a value the record can't do without,
  such as a designator, is missing, and the record is skipped.
- ``AIXMRecordError/invalidValue(feature:id:field:value:)``: a value couldn't be parsed. The
  record is read without it, or skipped if it can't do without it.
- ``AIXMRecordError/unresolvedReference(feature:id:reference:)``: a reference names no
  feature in the message, and the record that depends on it is skipped.

#### Domain-Restricted Data

Coded values — aerodrome types, surface compositions, obstacle types, runway point roles,
declared distance types — are read into enums such as ``AirportType``, ``SurfaceComposition``,
and ``ObstacleType``. AIXM lets every code list carry `OTHER`, optionally followed by text
(`OTHER:MAST`); both read as the enum's `other` case.

A code that is in neither the code list nor this form is *not* mapped to `other`. It is
reported as ``AIXMRecordError/invalidValue(feature:id:field:value:)``, with the code as the
value, and the property is `nil`. A new code in a data set is something your code has never
been written to handle, so SwiftAIXM tells you about it rather than passing it along as if it
were understood. Collect the errors to see what a data set contains that SwiftAIXM doesn't
know about:

```swift
var unknownCodes = Set<String>()
let dataset = try AIXMDataset(url: fileURL) { error in
  if case let AIXMRecordError.invalidValue(feature, _, field, value) = error {
    unknownCodes.insert("\(feature).\(field) = \(value)")
  }
}
```
