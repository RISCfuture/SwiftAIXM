# SwiftAIXM

- Use `Location` for positions, with its `elevation` where the data set gives one, rather than
  separate latitude, longitude, and elevation properties.
- Make model properties read-only (`let`). If they must be read-write for initialization
  purposes, use `private(set)`.
- Represent coded values as enums with an `init?(code:)` that accepts the published code-list
  values, any spellings the other formats use (AIXM 4.5, OFMX), and `OTHER` or `OTHER:<text>`
  as `other`. Anything else is reported through the builder's `code(...)` helper as an
  `AIXMRecordError.invalidValue`, never mapped to `other` or a default.
- When building enums or other custom types, you MUST use live data downloaded by
  SwiftAIXM_E2E to discover all possible values (`swift run -c release SwiftAIXM_E2E`, then
  look in `.SwiftAIXM_TestData/<cycle>/`). Do NOT rely on the test fixtures in
  `Tests/SwiftAIXMTests/Fixtures` - they are trimmed and incomplete. Use the AIXM 5.1 code
  lists and the OFMX schema to interpret the values you find.
- Report a problem with a single record through the error callback and keep reading; throw
  `AIXMError` only when the document can't be read at all.
- Read a new model property from both AIXM 5.1 and OFMX where the format has it, and document
  it as absent from the other in `Working with Data Sets.md` where it doesn't.
- The package builds and tests on Linux with FoundationXML. `String(localized:)` there is the
  shim in `LinuxLocalization.swift`, which does not support `format:` interpolation, and
  `XMLParser.delegate` differs in ownership between Darwin and Linux.
- Edge cases are tested with small documents written with `AIXM51Document` and `OFMXDocument`
  in `Tests/SwiftAIXMTests/Support`; realistic paths use the trimmed real fixtures.
