# Change Log

## [1.0.0] - 2026-10-31

Initial release.

Reads aerodromes, runways, runway directions (thresholds, declared distances, glide
paths, visual glide slope indicators), and obstacles from AIXM 5.1 and 5.1.1
`AIXMBasicMessage` documents and from open flightmaps OFMX snapshots, into one model.
Documents are streamed, AIXM 5.1 time slices are resolved for an effective date, and
records that can't be read in full are reported through an error callback.

- `AIXMDataset` detects the format from the root element and throws `AIXMError` for a
  missing file, malformed or truncated XML, or a document that is not a data set
- AIXM 5.1 time slices: the `BASELINE` or `SNAPSHOT` slice in effect on the effective date,
  taking the highest sequence and correction number; features whose lifetime has ended are
  dropped. GML times without a time zone, and dates without a time, are read as UTC
- AIXM 5.1 references, by `urn:uuid:` or local `#` reference, are resolved once the whole
  message is read; a reference that names no feature is reported
- Declared distances are taken from the threshold, then the displaced threshold, then the
  longest value across other centre-line points and scheduled values. OFMX distances prefer
  all-day values to daytime ones
- OFMX places a runway direction's position at its displaced threshold when the threshold
  is displaced, and at the threshold otherwise
- Obstacles have point, line, or surface parts, with each part's top elevation and height.
  Positions are read in their reference system's axis order, so CRS84 (longitude first) and
  EPSG:4326 (latitude first) both read correctly
- Code lists are domain-restricted: `AirportType`, `SurfaceComposition`, and `ObstacleType`
  read `OTHER` and `OTHER:<text>` as `other`, and a code outside the list is reported as
  `AIXMRecordError.invalidValue` rather than accepted. An obstacle's lighting given as
  `OTHER` reads as unknown
- DocC documentation, with articles on getting started and on how each format is read
- `SwiftAIXM_E2E` downloads the live open flightmaps and NATS data sets for an AIRAC
  cycle, or reads local files, and writes a JSON report of record counts and grouped record
  errors that can be compared with an earlier cycle's
