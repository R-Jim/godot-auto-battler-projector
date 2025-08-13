# Agent Guidelines for Go Project

This document outlines the conventions and commands for agents operating within this Go codebase.

## Build, Lint, and Test Commands

*   **Build All:** `go build ./...`
*   **Lint All:** `go vet ./...`
*   **Format All:** `go fmt ./...`
*   **Run All Tests:** `go test ./...`
*   **Run Single Test:** `go test -run <TestName> ./<package_path>`
    *   Example: `go test -run TestNewBattleManager ./battle`

## Code Style Guidelines

*   **Imports:** Group standard library imports, then third-party imports, separated by a newline.
*   **Formatting:** Adhere strictly to `gofmt` standards.
*   **Types:** Use clear and idiomatic Go type definitions.
*   **Naming Conventions:**
    *   Packages: Short, all lowercase (e.g., `battle`).
    *   Structs/Public Identifiers: `CamelCase`.
    *   Private Identifiers: `camelCase`.
    *   Constants: `CamelCase`.
*   **Error Handling:** Functions returning errors should use the `(result, error)` pattern. Check errors immediately after function calls.
*   **Comments:** Use `//` for single-line comments. `TODO` comments are used for pending work.

## Project structure
```
/your-project
├── cmd/
│   └── game-server/
│       ├── main.go
│       └── ...
│
├── internal/
│   ├── battle/
│   │   ├── battle_manager.go
│   │   ├── battle_field.go
│   │   └── receiver.go
│   └── ...
│
├── pkg/
│   ├── battle_logic/
│   │   ├── v1/
│   │   |   ├── types.go
│   │   │   └── combat_logic.go
│   │   │   └── combatant_logic.go
│   │   ├── v2/
│   │   |   ├── types.go
│   │   │   └── combat_logic.go
│   │   │   └── combatant_logic.go
│   │   └── ...│
├── go.mod
└── go.sum
```

## Cursor/Copilot Rules

No specific Cursor or Copilot rule files were found in this repository.
