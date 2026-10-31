# SwiftAIXM: AIXM aeronautical data library for Swift

[![CI](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/ci.yml/badge.svg)](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/ci.yml)
[![Documentation](https://github.com/RISCfuture/SwiftAIXM/actions/workflows/doc.yml/badge.svg)](https://riscfuture.github.io/SwiftAIXM/)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2026+%20|%20iOS%2026+%20|%20tvOS%2026+%20|%20watchOS%2026+%20|%20visionOS%2026+%20|%20Linux-blue.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

SwiftAIXM is a Swift library that reads the aeronautical data sets air navigation service
providers publish in AIXM, the Aeronautical Information Exchange Model. It reads two kinds of
document:

- **AIXM 5.1 and 5.1.1** `AIXMBasicMessage` documents, such as the UK AIP data set published by
  NATS and the obstacle data sets published by NATS, Austro Control, and the Swiss Federal Office
  of Civil Aviation.
- **OFMX** snapshots from [open flightmaps](https://www.openflightmaps.org), a dialect of
  AIXM 4.5, which cover much of Europe and southern Africa.

Both are read into the same model, made of structs and enums that are easy to use and take
advantage of common Swift paradigms: lengths and angles are `Measurement`s, positions are
`Location`s, and every type is `Codable`, so a data set can be read once and stored with the
`Coder` of your choice. The format is detected from the document, and documents are streamed,
so data sets of several hundred megabytes are read without being held in memory.

The design goal of SwiftAIXM is _domain-restricted data as much as possible_. Wherever possible,
SwiftAIXM avoids representing data as open-ended types such as strings. Instead, enums and other
types with small domains are preferred. A code that is not in its AIXM code list is reported
through the error callback rather than accepted. This has maintainability implications -- as
the upstream data changes, SwiftAIXM is more likely to report errors and need work to keep up --
but it also results in a library that's more in harmony with the design goals of the Swift
language itself (type safety, compile-time checks, etc.), and one that tells you when a data set
contains something your code was never written to handle.

## What records can I parse with this?

- Aerodromes and heliports, with their reference points, elevations, and magnetic variation
- Runways and helicopter final approach and takeoff areas, with their dimensions and surfaces
- Runway directions, with their bearings, thresholds, displaced thresholds, and touchdown zone
  elevations
- Declared distances (TORA, TODA, ASDA, LDA, and threshold displacement)
- ILS glide paths and visual approach slope indicators (PAPI, VASI)
- Obstacles, as points, lines, or surfaces, with their top elevations and heights

AIXM 5.1 time slices are resolved for the effective date you choose.

## Installation

SwiftAIXM is a Swift Package Manager project. To use SwiftAIXM, add this project to your
`Package.swift` file:

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

SwiftAIXM requires Swift 6.2 or later, and runs on macOS 26, iOS 26, watchOS 26, tvOS 26, and
visionOS 26 or later, and on Linux.

## Usage

Read a data set from a file or from data in memory with `AIXMDataset`. AIXM 5.1 features carry
time slices; pass the date whose data you want, usually the start of an AIRAC cycle, as
`effectiveDate`:

```swift
import SwiftAIXM

let dataset = try AIXMDataset(url: fileURL, effectiveDate: cycleStart) { error in
    print("Skipped: \(error.localizedDescription)")
}
```

A document that can't be read at all throws an `AIXMError`. A record that can't be read in full
is passed to the error callback as an `AIXMRecordError`, and is skipped or read without the value
at fault; reading continues either way.

Aerodromes are in `airports`, each with its runways and their directions:

```swift
for airport in dataset.airports {
    for direction in airport.runways.flatMap(\.directions) {
        print(airport.designator, direction.designator, direction.declaredDistances.TORA ?? "–")
    }
}
```

and obstacles are in `obstacles`, each with one or more parts:

```swift
let tallest = dataset.obstacles.flatMap(\.parts).compactMap(\.topElevation).max()
```

Every model type is `Codable`, so you can keep just the records you need and store them:

```swift
let data = try JSONEncoder().encode(dataset.airports.filter { $0.type?.hasRunways == true })
```

See the documentation for how each format is read: how declared distances are chosen when a
data set declares several, where OFMX places a displaced threshold, and how obstacle geometry and
coordinate axis order are handled.

## Documentation

Online API documentation and articles are available at
<https://riscfuture.github.io/SwiftAIXM/documentation/swiftaixm/>

DocC documentation is available, including articles and API documentation. For Xcode
documentation, you can run

```sh
swift package generate-documentation --target SwiftAIXM
```

to generate a docarchive at `.build/plugins/Swift-DocC/outputs/SwiftAIXM.doccarchive`. You can
open this docarchive file in Xcode for browseable API documentation. Or, within Xcode, open the
SwiftAIXM package in Xcode and choose **Build Documentation** from the **Product** menu.

## Tests

Testing is done using Swift Testing:

```sh
swift test
```

The test fixtures are trimmed from data published by open flightmaps
(<https://www.openflightmaps.org>), NATS (UK AIP data sets), and skyguide / the Swiss Federal
Office of Civil Aviation (obstacle data). The time-slice fixture is synthetic, and edge cases are
covered by small documents written in the tests themselves.

A `SwiftAIXM_E2E` target is also available to do an end-to-end test against real data. Without
arguments, it downloads the live data sets for the AIRAC cycle in effect — the open flightmaps
OFMX snapshot of every region, and the NATS UK AIP and obstacle data sets — and parses them,
summarizing what it read and grouping the record errors by feature, field, and code:

```sh
swift run -c release SwiftAIXM_E2E
swift run -c release SwiftAIXM_E2E --cycle next --source ofmx/lovv --source uk
```

It also parses files you have already downloaded:

```sh
swift run -c release SwiftAIXM_E2E --date 2026-10-29 EG_AIP_DS_FULL_20261029.xml ofmx_lo.ofmx
```

`--report` writes the run as JSON, and `--baseline` compares it with an earlier report; the run
fails when a data set can't be read or when a record error appears that the baseline didn't
have. The AIRAC Watch workflow uses these to check each cycle as soon as it is published and to
file an issue when a data set starts using a code SwiftAIXM doesn't know.

## License

SwiftAIXM is available under the MIT license. See the LICENSE file for details.
