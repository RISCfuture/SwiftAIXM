# ``SwiftAIXM``

Read aerodromes, runways, and obstacles from AIXM data sets.

## Overview

SwiftAIXM reads the aeronautical data sets that air navigation service providers publish
in AIXM, the Aeronautical Information Exchange Model:

- **AIXM 5.1 and 5.1.1** `AIXMBasicMessage` documents, such as ICAO AIP data sets and
  obstacle data sets.
- **OFMX** snapshots from [open flightmaps](https://www.openflightmaps.org), a dialect of
  AIXM 4.5.

Both are read into the same model: ``Airport`` records with their ``Runway``s and
``RunwayDirection``s, and ``Obstacle`` records. The format is detected from the document,
and documents are streamed, so data sets of several hundred megabytes are read without
being held in memory.

```swift
let dataset = try AIXMDataset(url: fileURL, effectiveDate: cycleStart) { error in
  print("Skipped: \(error.localizedDescription)")
}
for airport in dataset.airports {
  for direction in airport.runways.flatMap(\.directions) {
    print(airport.designator, direction.designator, direction.declaredDistances.TORA ?? "–")
  }
}
```

### Time slices

AIXM 5.1 features carry time slices, each valid for a period. SwiftAIXM reads the
`BASELINE` or `SNAPSHOT` slice in effect on the effective date you pass, and drops
features whose lifetime has ended by then.

### Declared distances

AIXM 5.1 data sets attach declared distances to runway centre-line points. Distances on
the threshold and displaced threshold come first. Some data sets attach them instead to
points with no role, alongside distances for takeoffs from intersections, and a distance
may list several scheduled values. In both cases the longest value is the full-length
distance available without restriction, so that is the one SwiftAIXM reports.

### Errors

Problems that prevent reading the document at all throw ``AIXMError``. Problems with a
single record are passed to the error callback as ``AIXMRecordError``; the record is
skipped or the affected value omitted, and reading continues.

## Topics

### Reading a Data Set

- ``AIXMDataset``
- ``AIXMError``
- ``AIXMRecordError``

### Aerodromes

- ``Airport``
- ``AirportType``
- ``Runway``
- ``RunwayDirection``
- ``DeclaredDistances``
- ``Glidepath``
- ``VisualGlideSlope``
- ``SurfaceComposition``

### Obstacles

- ``Obstacle``
- ``ObstaclePart``
- ``ObstacleGeometry``
- ``ObstacleType``

### Shared Types

- ``Location``
