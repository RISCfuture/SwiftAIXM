# SwiftAIXM

[![Build and Test](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/ci.yml/badge.svg)](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/ci.yml)
[![Documentation](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/doc.yml/badge.svg)](https://riscfuture.github.io/SwiftAIXM/)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-blue.svg)](https://swift.org)

Read aerodromes, runways, and obstacles from AIXM data sets.

## Overview

SwiftAIXM reads the aeronautical data sets that air navigation service providers
publish in AIXM, the Aeronautical Information Exchange Model:

- **AIXM 5.1 and 5.1.1** `AIXMBasicMessage` documents, such as ICAO AIP data sets
  and obstacle data sets.
- **OFMX** snapshots from [open flightmaps](https://www.openflightmaps.org), a
  dialect of AIXM 4.5.

Both are read into the same model: airports with their runways and runway
directions (thresholds, declared distances, glide paths), and obstacles. The
format is detected from the document, and documents are streamed, so data sets
of several hundred megabytes are read without being held in memory.

### Design Philosophy

- **Domain-restricted data**: AIXM code lists are typed, while keeping any
  `OTHER:` value a data set carries.
- **Foundation integration**: lengths and angles are `Measurement`s.
- **Strict parsing**: a document that can't be read throws; a record that can't
  be read in full is reported through a callback and skipped, never silently
  accepted.

## Requirements

- Swift 6.2+
- macOS 26+, iOS 26+, watchOS 26+, tvOS 26+, visionOS 26+, or Linux

## Installation

Add SwiftAIXM to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RISCfuture/SwiftAIXM", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftAIXM"]
)
```

## Usage

```swift
import SwiftAIXM

let dataset = try AIXMDataset(url: fileURL, effectiveDate: cycleStart) { error in
    print("Skipped: \(error.localizedDescription)")
}

for airport in dataset.airports {
    for direction in airport.runways.flatMap(\.directions) {
        print(airport.designator, direction.designator, direction.declaredDistances.TORA ?? "–")
    }
}
```

AIXM 5.1 features carry time slices; pass the date whose data you want as
`effectiveDate`. See the [documentation](https://riscfuture.github.io/SwiftAIXM/)
for how declared distances and obstacle geometry are read.

## Testing

```sh
swift test
```

The end-to-end target parses real data set files and summarizes what it read:

```sh
swift run SwiftAIXM_E2E --date 2026-10-29 EG_AIP_DS_FULL_20261029.xml ofmx_lo.ofmx
```

The test fixtures are trimmed from data published by open flightmaps
(<https://www.openflightmaps.org>), NATS (UK AIP data sets), and skyguide / the
Swiss Federal Office of Civil Aviation (obstacle data). Their time-slice fixture
is synthetic.

## License

SwiftAIXM is available under the MIT license. See the LICENSE file for details.
