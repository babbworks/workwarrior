# Dev Notes

Implementation notes, known approximations, deviations from reference behavior,
and technical debt. Each file documents one area. These are not bugs — they are
intentional simplifications or constraints that a future developer needs to know
about before changing the affected code.

Files here supplement code comments: the code itself may give no indication that
a behavior is approximate or constrained, so these notes provide the context.

## Index

| File | Service | Summary |
|---|---|---|
| [stream-dey-approximation.md](stream-dey-approximation.md) | stream / viz | Dey signal synthesized from event density when D-op samples absent |
| [viz-terminal-layout-constraint.md](viz-terminal-layout-constraint.md) | viz | Why terminal viz renders vertically rather than side-by-side |
