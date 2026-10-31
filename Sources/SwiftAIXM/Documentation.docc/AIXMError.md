# ``SwiftAIXM/AIXMError``

## Overview

An `AIXMError` is thrown when a document can't be read at all. Problems with individual
records are reported through the error callback as ``AIXMRecordError`` instead; see
<doc:Working-with-Data-Sets>.

## Topics

### Errors

- ``fileNotFound(_:)``
- ``malformedXML(reason:line:)``
- ``unrecognizedFormat(rootElement:)``

### Describing the Error

- ``errorDescription``
- ``failureReason``
