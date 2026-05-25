# Airi Local Qwen CLI Spike

This spike tests the technical core of Airi without UI:

- local Qwen planning through MLX
- visible task splitting
- local tool simulation
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

Qwen only understands and plans. Airi's Swift code remains responsible for tools,
validation, review, and later writing to macOS APIs such as EventKit.
