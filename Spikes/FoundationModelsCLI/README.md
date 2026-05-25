# Airi Local Qwen CLI Spike

This spike tests the technical core of Airi without UI:

- local Qwen planning through MLX
- visible task splitting
- second-pass calendar field extraction
- deterministic local resolution
- calendar capability proposals with ready/needs-clarification status
- a transparent step-by-step trace of what happens

It does not create real calendar events.

## Run

```bash
cd Spikes/FoundationModelsCLI
swift run AiriLocalSpike "Plane Zahnarzt naechsten Montag um 9 und Call mit Anna Mittwoch 14 Uhr"
```

## Test

```bash
cd Spikes/FoundationModelsCLI
swift test
```

By default it uses:

```text
/Users/robyn/.lmstudio/models/mlx-community/Qwen3.5-9B-MLX-4bit
```

You can override paths with:

```bash
export AIRI_QWEN_MODEL_PATH="/path/to/model"
export AIRI_MLX_GENERATE_PATH="/path/to/mlx_lm.generate"
```

## Current Shape

Qwen runs in two explicit steps:

1. Split the user request into typed tasks.
2. For every `calendarEvent`, extract calendar fields:

```json
{
  "type": "calendarEvent",
  "title": "Call mit Anna",
  "datePhrase": "Mittwoch",
  "timePhrase": "14 Uhr",
  "people": ["Anna"]
}
```

Swift then resolves date phrases, normalizes times, chooses the default calendar,
and asks `CalendarCapability` to produce reviewable proposals. A proposal is either
`ready` or `needs clarification`. Later, only ready proposals should be allowed to
write to macOS APIs such as EventKit.

Example clarification:

```text
Clarification [date]: Das Datum "01. Mai" ist uneindeutig: date is in the past and no year was given. Welches Datum meinst du?
```

Model JSON is decoded strictly. If Qwen returns malformed JSON, Airi reports the
error instead of repairing or guessing.

The date resolver is deterministic and covered by tests for:

- `heute`
- `morgen`
- `übermorgen`
- `Mittwoch`
- `nächste Woche Mittwoch`
- `übernächste Woche Mittwoch`
- `01. Mai`
- `01. Mai 2027`

The time resolver and calendar capability are also covered by tests.
