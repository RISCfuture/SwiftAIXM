# ``SwiftAIXM``

Read aerodromes, runways, and obstacles from AIXM data sets.

## Overview

SwiftAIXM reads the aeronautical data sets that air navigation service providers publish in
AIXM, the Aeronautical Information Exchange Model:

- **AIXM 5.1 and 5.1.1** `AIXMBasicMessage` documents, such as the UK AIP data set published
  by NATS and the obstacle data sets published by NATS, Austro Control, and the Swiss Federal
  Office of Civil Aviation.
- **OFMX** snapshots from [open flightmaps](https://www.openflightmaps.org), a dialect of
  AIXM 4.5.

Both are read into the same model: ``Airport`` records with their ``Runway``s and
``RunwayDirection``s — thresholds, declared distances, glide paths, and visual glide slope
indicators — and ``Obstacle`` records with their footprints. The format is detected from the
document, and documents are streamed, so data sets of several hundred megabytes are read
without being held in memory. Every model type is `Codable`, so a data set can be read once
and stored with the encoder of your choice.

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

The design goal of SwiftAIXM is _domain-restricted data as much as possible_. Wherever it
can, SwiftAIXM represents data with enums and measurements rather than open-ended strings
and numbers. A code that is not in its AIXM code list is reported through the error
callback rather than accepted, so as the upstream data changes, SwiftAIXM tells you about it
instead of quietly passing along values your code was never written to handle.

## Topics

### Essentials

- <doc:Getting-Started>
- <doc:Working-with-Data-Sets>
- ``AIXMDataset``

### Aerodromes

- ``Airport``
- ``AirportType``
- ``Runway``
- ``SurfaceComposition``
- ``RunwayDirection``
- ``DeclaredDistances``
- ``Glidepath``
- ``VisualGlideSlope``

### Obstacles

- ``Obstacle``
- ``ObstaclePart``
- ``ObstacleGeometry``
- ``ObstacleType``

### Positions

- ``Location``

### Errors

- ``AIXMError``
- ``AIXMRecordError``
