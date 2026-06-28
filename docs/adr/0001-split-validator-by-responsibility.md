# Split Validator by responsibility

`Blank.Schema.Validator` validated options for two independent systems: schema `@derive` options and field definition options. Folding it into `Blank.Schema` would have made `Blank.Field` depend on `Blank.Schema` for validation — increasing coupling between two subsystems that should be independent. Instead, schema validation moved to `Blank.Schema.Options` (an internal module in the protocol file) and field validation moved to `Blank.Field`. The coupling between Schema and Field (Schema needs field schemas to validate `@derive` options) is now explicit: `Blank.Schema.Options` calls `Blank.Field.__aggregate_field_schemas__/0`.

## Considered Options

- **Split by responsibility** (chosen) — field validation in `Blank.Field`, schema validation in `Blank.Schema.Options`. Improves locality for both systems. The cross-dependency is explicit.
- **Keep as neutral module** — rename to `Blank.Options.Validator` or similar. Less churn but still a shared module serving two masters.
- **Collapse into Schema** — would make Field depend on Schema for validation, increasing coupling.
