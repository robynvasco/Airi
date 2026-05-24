# Airi

**A local Mac copilot for actions.**

Airi is an open-source, local-first macOS app that turns natural language into safe,
reviewable Mac actions. It is designed for the gap between what macOS can technically
do and what Siri, Shortcuts, and individual apps still make awkward.

The first goal is simple: say something messy like "create these five calendar
events", review Airi's structured proposal, and let your Mac do the boring part.

## Principles

- **Local first:** no login, no analytics, no hidden cloud calls.
- **Apple Intelligence-native:** use Apple's on-device Foundation Models where they
  fit, especially for extraction, rewriting, summarization, and tool use.
- **Actions over answers:** Airi is not another chatbot. It should help the Mac do
  things.
- **Reviewable by design:** AI produces proposals. Capabilities execute actions only
  after validation and, for meaningful changes, user approval.
- **Modular from day one:** calendar, reminders, notes, files, shortcuts, windows,
  and future integrations live behind clear capability contracts.
- **Open source trust:** privacy claims should be verifiable in code.

## Initial MVP

The first useful version should focus on a small set of delightful, local workflows:

1. Global command palette for text input.
2. Dictated or typed batch calendar creation.
3. Batch reminders from natural language.
4. Notes-to-actions extraction.
5. Shortcuts discovery and execution.
6. Local proposal and execution history.
7. Permission dashboard for Calendar, Reminders, Notes, Accessibility, and Shortcuts.

## Architecture

Airi separates understanding from doing:

```text
User input
  -> local model interpretation
  -> typed proposal
  -> deterministic validation
  -> user review
  -> capability execution
  -> local audit log
```

The model never directly mutates the system. It creates structured proposals. Only
registered capabilities can execute actions, and each capability declares its required
permissions and execution behavior.

See [docs/architecture-rfc.md](docs/architecture-rfc.md) for the first technical
direction.

## Spikes

- [Foundation Models CLI](Spikes/FoundationModelsCLI/README.md): tests local model
  availability, tool calling, dynamic guided generation, and deterministic validation
  without any UI.

## Status

Airi is at the product and architecture stage. The repository is intentionally small
until the core capability system is clear.
