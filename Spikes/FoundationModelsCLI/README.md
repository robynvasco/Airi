# Airi Foundation Models CLI Spike

This spike tests the technical core of Airi without UI:

- Foundation Models availability
- guided generation with `DynamicGenerationSchema`
- tool calling with local Swift tools
- a typed calendar proposal printed to the terminal

It does not create real calendar events.

## Run

```bash
cd Spikes/FoundationModelsCLI
swift run AiriFoundationSpike "Plane Zahnarzt naechsten Montag um 9 und Call mit Anna Mittwoch 14 Uhr"
```

The machine must support Apple Intelligence, Apple Intelligence must be enabled, and
the on-device model must be ready.

## Toolchain note

This spike intentionally uses `DynamicGenerationSchema` instead of `@Generable` and
`@Guide`. On some machines, the macOS 26 Command Line Tools include the Foundation
Models framework but do not include Apple's `FoundationModelsMacros` compiler plugin.
The dynamic schema path lets us test model availability and tool calling without that
macro plugin.

If a future macro-based spike fails with:

```text
plugin for module 'FoundationModelsMacros' not found
```

install/select a full Xcode that includes the macOS 26 SDK and the Foundation Models
macro plugin:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
