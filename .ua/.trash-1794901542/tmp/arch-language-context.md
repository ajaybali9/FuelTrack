## Language Context: swift
# Swift Language Prompt Snippet

## Key Concepts

- **Optionals and Optional Chaining**: `Type?` wraps values that may be nil; `?.` chains safely
- **Protocols and Protocol Extensions**: Define contracts with default implementations via extensions
- **Value Types vs Reference Types**: Structs and enums are value types; classes are reference types
- **Closures**: Self-contained blocks of functionality that capture surrounding context
- **Property Wrappers**: `@State`, `@Binding`, `@Published` encapsulate property storage logic
- **Result Builders**: `@ViewBuilder`, `@resultBuilder` enable declarative DSL syntax
- **Actors and Structured Concurrency**: `actor` types for data isolation; `async let`, `TaskGroup`
- **Generics**: Type parameters with `where` clauses and associated type constraints
- **Enums with Associated Values**: Each case can carry distinct typed payloads
- **Extensions**: Add methods, computed properties, and protocol conformance to existing types

## Import Patterns

- `import Foundation` — core library with data types, collections, networking
- `import UIKit` — iOS UI framework for traditional view controller architecture
- `import SwiftUI` — declarative UI framework with reactive state management
- `@testable import ModuleName` — import with internal access for unit testing

## File Patterns

- `Package.swift` — Swift Package Manager manifest defining targets and dependencies
- `*.xcodeproj` / `*.xcworkspace` — Xcode project and workspace configuration
- `AppDelegate.swift` — UIKit application lifecycle entry point
- `App.swift` — SwiftUI application entry point using `@main`
- `Tests/` — test target directory following SPM or Xcode conventions

## Common Frameworks

- **SwiftUI** — Declarative UI framework with reactive data flow
- **UIKit** — Imperative UI framework using view controllers and Auto Layout
- **Vapor** — Server-side Swift web framework with async support
- **Combine** — Reactive framework for processing values over time
- **Core Data** — Object graph and persistence framework

## Example Language Notes

> Uses `@Published` property wrapper to automatically notify SwiftUI views of state
> changes. When the wrapped value mutates, the property wrapper triggers `objectWillChange`
> on the enclosing `ObservableObject`, causing dependent views to re-render.
>
> Protocol extensions provide default implementations, allowing types to conform by
> simply declaring conformance — no method body needed if defaults suffice.

## Language Context: markdown
# Markdown Language Prompt Snippet

## Key Concepts

- **Heading Hierarchy**: `#` through `######` for document structure, with h1 as the title
- **Front Matter**: YAML metadata between `---` delimiters at the top of the file
- **Fenced Code Blocks**: Triple backticks with optional language identifier for syntax highlighting
- **Reference-Style Links**: `[text][ref]` with `[ref]: url` definitions, useful for repeated URLs
- **Tables**: Pipe-delimited columns with alignment markers (`:---`, `:---:`, `---:`)
- **Admonitions**: Blockquote-based callouts (`> **Note:**`, `> **Warning:**`) for emphasis
- **Task Lists**: `- [ ]` and `- [x]` for checklists in issue trackers and READMEs
- **HTML Embedding**: Raw HTML allowed inline for features Markdown does not support natively

## Notable File Patterns

- `README.md` — Project overview and entry point for new contributors (high-value)
- `CONTRIBUTING.md` — Contribution guidelines, code style, PR process
- `CHANGELOG.md` — Version history following Keep a Changelog or similar format
- `docs/**/*.md` — Documentation directory with guides, API references, tutorials
- `*.md` in source directories — Co-located documentation for modules or packages
- `ADR-*.md` or `adr/*.md` — Architecture Decision Records

## Edge Patterns

- Markdown files `documents` the code components they describe or reference
- Links to other `.md` files create `related` edges between documentation nodes
- Code block references mentioning file paths may imply `documents` edges to those files
- README files in subdirectories typically `documents` the module at that path

## Summary Style

> "Project overview documentation with N sections covering installation, usage, and API reference."
> "Architecture Decision Record documenting the choice of [technology] for [purpose]."
> "Contributing guide with code style rules, testing requirements, and pull request process."

## Language Context: yaml
# YAML Language Prompt Snippet

## Key Concepts

- **Indentation-Based Nesting**: Whitespace-sensitive structure (spaces only, no tabs) defining hierarchy
- **Anchors and Aliases**: `&anchor` defines a reusable block, `*anchor` references it to avoid duplication
- **Merge Keys**: `<<: *anchor` merges anchor contents into the current mapping
- **Multi-Line Strings**: Literal block (`|`) preserves newlines, folded block (`>`) joins lines
- **Document Separators**: `---` starts a new document, `...` ends one (multi-document streams)
- **Tags and Types**: `!!str`, `!!int`, `!!bool` for explicit typing; custom tags for application-specific types
- **Flow Style**: Inline JSON-like syntax `{key: value}` and `[item1, item2]` for compact notation
- **Environment Variable Substitution**: `${VAR}` patterns used in docker-compose and CI configs

## Notable File Patterns

- `docker-compose.yml` / `docker-compose.yaml` — Multi-container Docker application definition
- `.github/workflows/*.yml` — GitHub Actions CI/CD workflow definitions
- `.gitlab-ci.yml` — GitLab CI/CD pipeline configuration
- `kubernetes/*.yaml` / `k8s/*.yaml` — Kubernetes resource manifests
- `*.config.yaml` — Application configuration files
- `mkdocs.yml` — MkDocs documentation site configuration
- `serverless.yml` — Serverless Framework configuration

## Edge Patterns

- YAML config files `configures` the code modules they control (e.g., database settings affect data layer)
- CI/CD YAML files `triggers` build and deployment pipelines
- docker-compose YAML `deploys` services and `depends_on` Dockerfiles
- Kubernetes YAML `deploys` and `provisions` application services

## Summary Style

> "Docker Compose configuration defining N services with networking, volumes, and health checks."
> "GitHub Actions workflow running tests on push and deploying to production on merge to main."
> "Kubernetes deployment manifest with N replicas, resource limits, and liveness probes."

## Language Context: json
# JSON Language Prompt Snippet

## Key Concepts

- **Strict Syntax**: No trailing commas, no comments (unlike JSONC or JSON5), double-quoted strings only
- **Data Types**: Objects, arrays, strings, numbers, booleans, and null — no undefined or date types
- **Nested Structure**: Arbitrary nesting depth for hierarchical configuration or data
- **Schema Validation**: JSON Schema (`$schema` keyword) for validating structure and types
- **JSONC**: JSON with Comments variant used by VS Code, tsconfig.json, and other tooling
- **JSON5**: Extended JSON allowing comments, trailing commas, unquoted keys, and more
- **JSON Lines** (`.jsonl`): One JSON object per line for streaming data processing

## Notable File Patterns

- `package.json` — Node.js project manifest with dependencies, scripts, and metadata
- `tsconfig.json` — TypeScript compiler configuration (actually JSONC)
- `.eslintrc.json` — ESLint linting rules and configuration
- `*.schema.json` — JSON Schema definitions for validation
- `composer.json` — PHP Composer project manifest
- `appsettings.json` — .NET application configuration
- `manifest.json` — Browser extension or PWA manifest

## Edge Patterns

- `package.json` `configures` the build toolchain and defines project dependencies
- `tsconfig.json` `configures` TypeScript compilation for all `.ts` files
- JSON Schema files `defines_schema` for API request/response validation
- Config JSON files `configures` the runtime behavior of the application

## Summary Style

> "Node.js project manifest defining N dependencies, build scripts, and project metadata."
> "TypeScript compiler configuration enabling strict mode with path aliases for monorepo packages."
> "JSON Schema defining the request/response structure for the user API endpoint."

