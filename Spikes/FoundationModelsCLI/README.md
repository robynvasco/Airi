# Airi Local Qwen CLI Spike

This spike tests the technical core of Airi without UI:

- local Qwen planning through MLX
- visible task splitting
- second-pass calendar field extraction
- deterministic local resolution
- draft calendar proposals
- a transparent step-by-step trace of what happens

It does not create real calendar events.

## Run

```bash
cd Spikes/FoundationModelsCLI
swift run AiriLocalSpike "Plane Zahnarzt naechsten Montag um 9 und Call mit Anna Mittwoch 14 Uhr"
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
builds draft proposals, validates them, and later writes to macOS APIs such as
EventKit.
