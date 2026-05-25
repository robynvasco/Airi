# Airi Architecture RFC

## Summary

Airi is a native macOS copilot for actions. It should feel like an intelligent system
layer for the Mac, but its internals should be conservative: local inference, typed
proposals, explicit permissions, deterministic execution, and a local audit trail.

## Non-goals

- Airi is not a general world-knowledge chatbot.
- Airi should not require a cloud account.
- Airi should not execute arbitrary shell commands as a default capability.
- Airi should not hide system mutations behind vague "agent" behavior.
- Airi should not depend on closed SaaS infrastructure for core workflows.

## Core Loop

```text
Input -> Intent -> Proposal -> Validation -> Approval -> Execution -> Log
```

### Input

Inputs can come from:

- command palette text
- dictation
- selected text
- share extensions
- future App Intents or Shortcuts triggers

### Intent

A local model provider should be used for language understanding tasks. The first
provider is Qwen through MLX:

- extracting calendar events from messy text
- turning notes into reminders
- classifying the requested capability
- summarizing local context
- rewriting titles or descriptions
- asking concise clarification questions

The model should produce small, strict JSON plans that Swift decodes into typed
structures. Swift owns validation, permissions, review, and execution.

### Proposal

A proposal is a typed, reviewable description of the actions Airi intends to perform.
It is not executable code.

Example:

```swift
struct CalendarBatchProposal {
    var events: [CalendarEventDraft]
    var unresolvedQuestions: [ClarificationQuestion]
    var confidence: Double
}
```

### Validation

Validation is deterministic Swift code. It checks:

- date and time completeness
- timezone assumptions
- duplicate events
- calendar permissions
- participant/contact ambiguity
- conflicting events
- missing required fields

### Approval

Airi should auto-execute only low-risk actions that the user has explicitly configured.
For meaningful mutations, especially calendar, reminder, file, message, and settings
changes, the default is preview-first.

### Execution

Only capabilities execute actions. The model never writes to EventKit, Reminders,
Notes, files, windows, or system settings directly.

### Log

Every execution should create a local audit entry:

- original input
- resolved capability
- proposal summary
- executed actions
- timestamp
- permission state
- errors or skipped actions

The log is local and user-visible.

## Capability System

Capabilities are the modular boundary of Airi.

```swift
protocol Capability {
    var id: String { get }
    var title: String { get }
    var requiredPermissions: [AiriPermission] { get }

    func propose(from input: UserIntent, context: LocalContext) async throws -> Proposal
    func validate(_ proposal: Proposal, context: LocalContext) async throws -> ValidationResult
    func execute(_ proposal: Proposal, context: LocalContext) async throws -> ExecutionResult
}
```

Initial built-in capabilities:

- Calendar
- Reminders
- Notes
- Shortcuts
- Clipboard
- Files
- Windows
- System settings

The public extension model can use the same concepts later, but v1 should keep all
capabilities built in until permissions, review, and logging are proven.

## Privacy Model

Airi should make privacy enforceable:

- no analytics dependency
- no login dependency
- no network entitlement in local-only builds
- local SQLite storage
- permission dashboard
- local-only model provider as the default
- visible indication if any future provider leaves the device

## Suggested Repository Shape

```text
Airi/
  App/
    CommandPalette/
    Settings/
  Core/
    Agent/
    Capabilities/
    Permissions/
    Proposals/
    Storage/
  Capabilities/
    Calendar/
    Reminders/
    Notes/
    Shortcuts/
    Clipboard/
    Files/
    Windows/
  Intelligence/
    QwenMLXPlanner.swift
    ModelProvider.swift
    PromptSchemas/
  docs/
    architecture-rfc.md
```

## First Vertical Slice

The first implementation should prove one complete path:

> "Create a dentist appointment next Monday at 9, a call with Anna on Wednesday at
> 14:00, and an all-day workshop in Hamburg on Friday."

Airi should:

1. parse multiple events from one input
2. resolve relative dates
3. detect ambiguity around contacts and missing durations
4. show a review screen
5. create events through EventKit
6. write a local audit entry

That vertical slice is enough to validate the product promise.
