# Getting Started

Read a data set and work with its aerodromes and obstacles.

## Overview

Add SwiftAIXM to your package's dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/RISCfuture/SwiftAIXM", from: "1.0.0")
]
```

and to the dependencies of the target that uses it:

```swift
.target(name: "YourTarget", dependencies: ["SwiftAIXM"])
```

### Reading a Data Set

Create an ``AIXMDataset`` from a file or from data in memory. SwiftAIXM recognizes the format
from the document's root element, so the same call reads an AIXM 5.1 message and an open
flightmaps OFMX snapshot:

```swift
import SwiftAIXM

let dataset = try AIXMDataset(url: URL(filePath: "EG_AIP_DS_FULL_20261029.xml"))
print(dataset.format)  // AIXM51
```

AIXM 5.1 data sets describe how each feature changes over time. Pass the date whose data you
want as the effective date — usually the start of the AIRAC cycle you are preparing for:

```swift
let cycleStart = try Date("2026-10-29T00:00:00Z", strategy: .iso8601)
let dataset = try AIXMDataset(url: fileURL, effectiveDate: cycleStart)
```

A document that can't be read at all throws ``AIXMError``. A record that can't be read in full
is passed to the error callback and skipped, or read without the value at fault; reading
continues either way:

```swift
var problems = [any Error]()
let dataset = try AIXMDataset(url: fileURL, effectiveDate: cycleStart) { problems.append($0) }
```

See <doc:Working-with-Data-Sets> for how each format is read and what the errors mean.

### Aerodromes and Runways

``AIXMDataset/airports`` holds each aerodrome with its ``Runway``s, and each runway with a
``RunwayDirection`` for each end it can be used from:

```swift
guard let southend = dataset.airports.first(where: { $0.ICAOIdentifier == "EGMC" }) else {
  return
}
for runway in southend.runways where runway.isFixedWing {
  for direction in runway.directions {
    let distances = direction.declaredDistances
    print(direction.designator, distances.TORA ?? "–", distances.LDA ?? "–")
  }
}
```

Lengths, elevations, and angles are `Measurement`s, so convert them to the unit you need:

```swift
if let lda = direction.declaredDistances.LDA {
  print(lda.converted(to: .feet).formatted())
}
```

### Obstacles

``AIXMDataset/obstacles`` holds each ``Obstacle`` with one or more ``ObstaclePart``s. A part's
``ObstaclePart/geometry`` is a point, a line, or a surface, and its
``ObstaclePart/topElevation`` is the elevation of its highest point above mean sea level:

```swift
let tallest = dataset.obstacles
  .flatMap(\.parts)
  .compactMap(\.topElevation)
  .max()
```

### Storing What You Read

Every model type is `Codable`. Large data sets take a moment to read, so you may want to read
one once, keep the records you need, and store them:

```swift
let paved = dataset.airports.filter { airport in
  airport.runways.contains { $0.composition?.isPaved == true }
}
let data = try JSONEncoder().encode(paved)
```
