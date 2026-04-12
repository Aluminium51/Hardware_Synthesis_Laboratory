# ADR-004 Filters on Readout

## Decision
Store raw frames in BRAM and apply filters only on the VGA readout path.

## Status
Accepted.

## Rationale
- supports live mode switching without recapture
- keeps camera capture path simpler
- fits the selected baseline filters well because they are per-pixel operations
