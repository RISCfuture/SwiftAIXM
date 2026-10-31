# Change Log

## [1.0.0] - 2026-10-31

Initial release.

Reads aerodromes, runways, runway directions (thresholds, declared distances, glide
paths, visual glide slope indicators), and obstacles from AIXM 5.1 and 5.1.1
`AIXMBasicMessage` documents and from open flightmaps OFMX snapshots, into one model.
Documents are streamed, AIXM 5.1 time slices are resolved for an effective date, and
records that can't be read in full are reported through an error callback.
