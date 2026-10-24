# Coding standards

Repo-specific rules for `blank`. A reviewer can check each rule against one diff hunk.
Generic Elixir idiom lives in the stack pack (`rule://stack-elixir`); choices between
alternatives live in `docs/adr/`.

## Extension seams

1. Declare a consumer option set as a NimbleOptions `@schema`; interpolate `NimbleOptions.docs(@schema)` into the `@moduledoc`; raise `Blank.Errors.InvalidConfigError.from_nimble/2` on invalid config. (`lib/blank/field.ex:277`, `lib/blank/schema.ex:100`)
2. Enter a Phoenix behaviour through `use Blank.Web` (`:live_view`, `:live_component`, `:controller`, `:html`, `:field`, `:stat`); never write a bare `use Phoenix.LiveView` or `use Phoenix.LiveComponent`. (`lib/blank/web.ex:60`)
3. Define an extension point as a behaviour in `Blank.<Capability>`, whose `__using__` injects `@behaviour` and `use Blank.Web`; put implementations in the plural sub-namespace (`Blank.Fields.*`, `Blank.Exporters.*`, `Blank.Authorization.RoleMappers.*`). (`lib/blank/field.ex:285`, `lib/blank/exporter.ex:11`)
4. Add a field adapter as `lib/blank/fields/<type>.ex` with `use Blank.Field`; implement `render_display/1` and `render_form/1` in `~H`, and `render_list/1` only when the display form is not enough. (`lib/blank/fields/text.ex:17`)

## Rendering

5. Build field URLs from the `path_prefix` assign and take `time_zone` from assigns; never read `socket.router`. (`lib/blank/components/field.ex:12`)
6. Name an admin page `Blank.Pages.<Name>Live` in `lib/blank/pages/<name>_live.ex`, declare `use Blank.AdminPage`, and extend a LiveView callback with `defoverridable` plus `super`. (`lib/blank/pages/users_live.ex:1`)
7. Keep admin-page templates as `.html.heex` files in `lib/blank/admin_page/`, embed them with `embed_templates`, and expose each one as a `@doc false` component with `attr` declarations. (`lib/blank/admin_page.ex:558`)

## Data and audit

8. Write a mutation as an `Ecto.Multi` pipeline that includes `Blank.Audit.multi/4`; name the audit action `"<resource>.<verb>"`. (`lib/blank/context.ex:273`)
9. Write an authentication event with `Blank.Audit.log!/3`; allow-list its params in `AuditLog.@allowed_params`. (`lib/blank/audit/audit_log.ex:76`)
10. Authorize through `Blank.Authorization.can?/3` with `%Blank.Scope{resource_type: atom}`; never call a policy module directly. (`lib/blank/admin_page.ex:464`)
11. Read config at call time with `Application.fetch_env!/2`; cache only the allowed-role set, through `Blank.Config`. (`lib/blank/config.ex:16`)
12. Define Blank's own schemas with `Blank.EctoSchema`, not `use Ecto.Schema`; use `:utc_datetime` timestamps. (`lib/blank/accounts/user.ex:12`)

## Docs and tests

13. Set `@moduledoc false` on an internal module; document only the consumer-facing modules and behaviours. (`lib/blank/context.ex:2`)
14. Mirror `lib/` in `test/blank/` as `<path>_test.exs`, and pick the case template by layer: `ExUnit.Case` for pure code, `TestApp.DataCase` for the DB, `Blank.ConnCase` for HTTP, `Blank.LiveViewCase` for LiveView. (`test/blank/fields/boolean_test.exs:1`)
15. Title each `describe` with the function under test (`"log!/3"`); start a test name with `returns`, `with` or `clicking`. Log in through the fixture and drive real admin routes with `live(conn, "/admin/...")`. (`test/blank/accounts_test.exs:19`, `test/support/blank_live_view_case.ex:34`)
