# ``SwiftAIXM/AIXMRecordError``

## Overview

Record errors are passed to the error callback of
``AIXMDataset/init(url:effectiveDate:errorCallback:)`` and
``AIXMDataset/init(data:effectiveDate:errorCallback:)`` as they are found. The record is
skipped, or read without the value at fault, and the rest of the data set is still read.

A code that is not in its AIXM code list is reported as
``invalidValue(feature:id:field:value:)`` rather than read as `other`, so that a data set
using a code SwiftAIXM doesn't know about is noticed. See <doc:Working-with-Data-Sets>.

## Topics

### Errors

- ``missingValue(feature:id:field:)``
- ``invalidValue(feature:id:field:value:)``
- ``unresolvedReference(feature:id:reference:)``

### Describing the Error

- ``errorDescription``
- ``failureReason``
