# Troubleshooting & FAQ

Common issues and their solutions. If your issue isn't listed here, check the [GitHub issues](https://github.com/TomGrozev/blank/issues) or open a new one.

## Installation & Setup

### "No blank.install task found"

**Problem:** Running `mix blank.install` fails with a "mix task not found" error.

**Solution:** Make sure Blank is in your `mix.exs` dependencies and you've run `mix deps.get`:

```elixir
def deps do
  [
    {:blank, "~> 0.1.0"}
  ]
end
```

```bash
mix deps.get
mix blank.install
```

### "Migrations not found after blank.install"

**Problem:** `blank.install` ran but `mix ecto.migrate` doesn't see Blank's migrations.

**Solution:** Run `mix ecto.migrate` after `mix blank.install`. The install task copies migrations into your project's `priv/repo/migrations`. If you're using a non-default migrations path or an umbrella app, pass the migrations path explicitly:

```bash
mix blank.install --migrations-path priv/repo/migrations
```

### "Tailwind styles not applied"

**Problem:** The admin panel renders but styles are missing — everything looks unstyled.

**Solution:** Check that `blank.install` added the Blank content paths to your Tailwind config. The install task modifies `assets/**/app.css` automatically, but if it missed the file or you're using a non-standard location, add it manually:

```css
/* assets/css/app.css */
@import "tailwindcss";
@source "../deps/blank/lib/**/*.*ex";
```

If you're using Tailwind v3, the syntax differs. Use `@source` for v4+ and `content` array for v3 in your `tailwind.config.js`:

```js
// tailwind.config.js (v3)
module.exports = {
  content: [
    "../deps/blank/lib/**/*.*ex"
  ]
}
```

Rerun or restart your asset build after the change.

---

## Authentication

### "No login path" boot error

**Problem:** The application fails to start with an error about no login path being available.

**Solution:** Blank must have at least one authentication method configured. Either:

1. **Enable local login** (the default, available everywhere):

   ```elixir
   config :blank, :auth, local_login: :enabled
   ```

2. **Configure at least one ueberauth provider** if local login is disabled:

   ```elixir
   config :ueberauth, Ueberauth,
     providers: [github: {Ueberauth.Strategy.Github, []}]
   ```

   When `local_login: :disabled`, Blank validates at boot that ueberauth providers exist. If neither is present, the app raises with an actionable error message.

### "Login page shows error about missing providers"

**Problem:** The login page at `/admin/log_in` shows a "Authentication methods are not configured" message.

**Solution:** Same root cause as above — both local login and ueberauth providers are absent. Check your config:

```elixir
# Check current config in IEx:
iex> Application.get_env(:blank, :auth)
```

You must either enable local login or configure at least one ueberauth provider. See the [Authentication guide](Authentication.md) for details.

### "Cannot login with local credentials"

**Problem:** The email/password form is not shown, or logging in with local credentials is rejected.

**Solution:** Check your `local_login` config:

```elixir
config :blank, :auth, local_login: :enabled
```

| Setting | Behaviour |
|---|---|
| `:enabled` | Local login always available. This is the default. |
| `:dev_only` | Local login available in `:dev`/`:test`. Shows a warning banner in production but login still works. |
| `:disabled` | No local login form is rendered. All authentication flows through ueberauth providers. |

If you need local login in production but currently have `:disabled`, change it to `:enabled`. If you're using `:dev_only` in production, the banner is a warning, not a blocker — login should still work.

### "Ueberauth callback fails"

**Problem:** Clicking an IdP provider button redirects correctly but the callback returns an error.

**Solution:** Verify your ueberauth provider configuration:

1. **Check client credentials** — the `client_id` and `client_secret` must match your IdP application registration.
2. **Check callback URL** — your IdP must be configured to redirect back to `<your-domain>/admin/auth/:provider/callback`.
3. **Check the strategy dependency** — the ueberauth strategy package must be in `mix.exs` and installed (`mix deps.get`).

Consult your ueberauth strategy's documentation for provider-specific setup. Blank's callback controller at `/admin/auth/:provider/callback` handles token exchange and user lookup automatically.

---

## Authorization

### "Admin panel is empty / no pages visible"

**Problem:** Logged into the admin panel but no navigation links or pages appear. The sidebar is empty.

**Solution:** Your policy module is returning `false` for all `can?/3` calls. Remember: **`DefaultPolicy` is closed by default** — it denies everything for non-`:system_admin` users.

Quick fix for development:

```bash
mix blank.user.new --email admin@example.com --password "SecurePass123!" --roles system_admin
```

Log in as this admin. `:system_admin` bypasses the policy module entirely — every page is accessible.

For production, write and configure a policy module:

```elixir
# lib/my_app/policy.ex
defmodule MyApp.Policy do
  use Blank.Authorization.Policy

  def policy(%{roles: roles}, :list, %{resource_type: :product}),
    do: :member in roles
end
```

Wire it in config:

```elixir
config :blank, :authorization, policy_module: MyApp.Policy
```

See the [Authorization guide](Authorization.md) for complete policy-writing instructions.

### "User cannot access a page they should have access to"

**Problem:** A user with the right roles still cannot access a specific admin page or action.

**Solution:** Work through this checklist:

1. **Check the user's roles** — inspect the `roles` field on the user record:

   ```elixir
   user = Blank.Accounts.get_user!(some_id)
   user.roles
   # => [:member, :content_editor]
   ```

2. **Validate roles are in the allowed-set** — use `Blank.Authorization.validate_roles/1`:

   ```elixir
   Blank.Authorization.validate_roles([:member, :content_editor])
   # => :ok
   ```

   If any role is not in the allowed-set, the user cannot hold it. Check your `config :blank, :authorization, roles: [...]` config — only roles listed there (plus the built-in `:system_admin` and `:member`) are valid.

3. **Check your policy module** — verify the `policy/3` clauses match the user's roles and the specific action/scope being checked. Remember that clauses match top-to-bottom and the catch-all returns `false`.

4. **Check the scope's `resource_type`** — the resource type in the scope must match the key used in your policy clauses. The key defaults to the downcased schema module name (e.g. `Post` → `:post`).

### "Role mapper returns invalid roles"

**Problem:** Users logging in via an IdP get an error or are assigned unexpected roles.

**Solution:** The role mapper returned roles not in the allowed-set. The allowed-set is the union of `:system_admin`, `:member`, and the roles listed in your config:

```elixir
config :blank, :authorization, roles: [:payment_manager, :content_editor]
```

Verify that:

1. Every role your IdP claims map to is in the allowed-set.
2. The role atoms in your role mapper config match exactly (atoms, not strings).
3. Your role mapper is correctly configured:

```elixir
config :blank, :authorization,
  role_mapper: {Blank.Authorization.RoleMappers.GitHub,
                [team_slug_to_role: %{"payments-team" => :payment_manager}]}
```

See the [Role Mappers guide](Role%20Mappers.md) for details on the built-in GitHub and OIDCC mappers.

---

## Admin Pages

### "Field not showing in admin page"

**Problem:** A schema field is missing from the admin index, show, or edit view.

**Solution:** Check the field's `:viewable` option. Its default is `true`, but you may have set it to `false`:

```elixir
@derive {
  Blank.Schema,
  fields: [
    internal_note: [viewable: false]
  ]
}
```

Also check that:

- Timestamps (`inserted_at`, `updated_at`) are excluded from edit views by default. They still appear on index and show views unless explicitly excluded from `show_fields`.
- The field is listed in `index_fields` / `show_fields` / `edit_fields` on your `use Blank.AdminPage` declaration. These lists filter which fields appear. If you specify them explicitly, only those fields are shown.
- Foreign keys are excluded from the default field list (e.g. `post_id` is hidden in favor of the `post` association). To include them, set `include_foreign_keys: true` in your `@derive` options.

### "Field is read-only but should be editable"

**Problem:** A field shows up on the edit page but is disabled/uneditable.

**Solution:** Check the field's `:readonly` option (default: `false`):

```elixir
@derive {
  Blank.Schema,
  fields: [
    email: [readonly: false],
    inserted_at: [readonly: true]
  ]
}
```

Note that the `id` and `__id__` fields are always read-only by default. Timestamps are excluded from edit views entirely — they aren't just read-only, they're absent.

### "Association field shows ID instead of name"

**Problem:** A `belongs_to` association field shows a numeric or UUID ID value instead of a human-readable name.

**Solution:** Set the `:display_field` option on the association field to specify which field to use for display:

```elixir
@derive {
  Blank.Schema,
  fields: [
    author: [module: Blank.Fields.BelongsTo, display_field: :name]
  ]
}
```

Blank will now display the author's `name` field instead of its primary key. The `:display_field` can be any field on the associated schema.

For more control over what's displayed (e.g. a computed full name), use the `:select` option with an Ecto dynamic expression:

```elixir
author: [
  module: Blank.Fields.BelongsTo,
  display_field: :full_name,
  select: quote(do: dynamic([a], fragment("concat(?, ' ', ?)", a.first_name, a.last_name)))
]
```

### "Search not working"

**Problem:** Typing in the search box on an index page returns no results, or a field doesn't appear in the advanced search filter.

**Solution:** Make sure the field has `searchable: true` in its field options:

```elixir
@derive {
  Blank.Schema,
  fields: [
    title: [searchable: true],
    description: [searchable: true]
  ]
}
```

Only fields with `searchable: true` appear in the advanced search dropdown. The simple search box (default mode) uses `ilike` matching across all `searchable` fields.

### "Sorting not working"

**Problem:** Clicking a column header to sort doesn't reorder results, or the field doesn't show as a sortable column.

**Solution:** Make sure the field has `sortable: true` in its field options:

```elixir
@derive {
  Blank.Schema,
  fields: [
    title: [sortable: true],
    price: [sortable: true]
  ]
}
```

Only fields with `sortable: true` render as clickable sort columns. You can also set a field as `sortable` but not `searchable`, or vice versa — they are independent options.

For association fields, set both `sortable: true` and `display_field:` to sort by the associated record's display field:

```elixir
author: [module: Blank.Fields.BelongsTo, sortable: true, display_field: :name]
```

---

## Audit Logging

### "Audit log is empty"

**Problem:** The audit log viewer at `/admin/audit` shows no entries despite performing CRUD operations in the admin panel.

**Solution:** Check that `Blank.Audit.Context` is wired into your router. The `blank_admin` macro includes it automatically — audit logging works inside admin pages without any extra configuration. But if you need audit logging in your own app routes, you must add the plug and hook manually:

```elixir
# lib/my_app_web/router.ex
import Blank.Audit.Context

# In your browser pipeline:
pipeline :browser do
  # ... other plugs ...
  plug :fetch_current_user       # must come before fetch_audit_context
  plug :fetch_audit_context
end

# In your live sessions:
live_session :default,
  on_mount: [
    # ... other hooks ...
    Blank.Audit.Context
  ] do
  # ...
end
```

> **Order matters.** The audit context plug reads `current_user` from conn/socket assigns, so it must appear *after* your authentication plug.

See the [Audit Logging guide](../howtos/Audit%20Logging.md) for full details.

### "Audit log not updating in real-time"

**Problem:** New audit entries don't appear in the viewer until the page is refreshed.

**Solution:** Check that PubSub is running. The audit log viewer subscribes to `Blank.PubSub` on the `"audit:logs"` topic for live updates. PubSub is started automatically as part of Blank's supervision tree (`Blank.Application`). Verify:

1. `Blank.Application` is in your app's supervision tree (it is by default when you add Blank as a dependency).
2. No firewall or proxy is blocking the LiveView WebSocket connection. Open your browser's developer tools, check the WebSocket tab, and confirm the LiveView socket connects successfully.
3. If you're running in a clustered or distributed environment, ensure the PubSub adapter is configured for cluster-wide broadcasting, not just local.

### "Custom audit event not appearing"

**Problem:** You're calling `Blank.Audit.log!/3` but the event doesn't show up in the audit log viewer.

**Solution:** Verify the call:

1. **Pass a valid `%User{}` struct** (or an audit context struct built from one) as the first argument. The audit context must have a `user` field set. For system-level events with no acting admin, use `Blank.Audit.AuditLog.system()`:

   ```elixir
   audit_context = Blank.Audit.AuditLog.system()
   Blank.Audit.log!(audit_context, "app.nightly_sync", %{count: 42})
   ```

2. **Use the `app.` prefix** for custom events. Built-in action prefixes (`accounts.`, wildcard `*.`) validate the params map and will raise if the params don't match:

   ```elixir
   # Correct — custom events use the app. prefix:
   Blank.Audit.log!(audit_context, "app.order_shipped", %{order_id: order.id})

   # Wrong — will raise InvalidParameterError:
   Blank.Audit.log!(audit_context, "myapp.order_shipped", %{order_id: order.id})
   ```

3. **Check the repo config** — `log!/3` inserts directly into the database using the configured `:repo`. Make sure `config :blank, repo: MyApp.Repo` is set.

---

## Database

### "ArangoDB adapter not working"

**Problem:** Running `blank.install` with ArangoDB fails or migrations don't work with ArangoDB.

**Solution:** Make sure you explicitly select the ArangoDB adapter when installing:

```bash
mix blank.install --adapter arango
```

The default adapter is `ecto_sql`. If you already ran `blank.install` without the `--adapter` flag, rerun it with the correct adapter to copy the right migration files:

```bash
# List available adapters:
mix blank.install --adapter arango
# Also accepts: ecto_sql
```

Also ensure `arangox_ecto` is in your dependencies (it's listed as optional in Blank):

```elixir
def deps do
  [
    {:arangox_ecto, "~> 2.0"}
  ]
end
```

### "Migration errors"

**Problem:** Running `mix ecto.migrate` after `blank.install` fails with migration errors.

**Solution:** Check that your Repo is configured correctly:

```elixir
config :blank, repo: MyApp.Repo
```

Also verify:

1. **Your database is accessible** — the Repo's database config must point to a running database.
2. **The migrations path** is correctly set in your `config :my_app, MyApp.Repo, ...` (for `ecto_sql`) or equivalent.
3. **The adapter matches** — if you installed with `--adapter arango`, your Repo should use the ArangoDB adapter, not `Ecto.Adapters.Postgres`/`Ecto.Adapters.SQLite3`.

---

## Performance

### "Admin panel is slow"

**Problem:** Pages load slowly, especially index pages with many records.

**Solution:** Performance issues in the admin panel are usually database-related. Work through these steps:

1. **Add database indexes** on frequently filtered and sorted fields. Every field with `searchable: true` or `sortable: true` generates `WHERE` and `ORDER BY` clauses that benefit from indexes:

   ```elixir
   # In a migration:
   create index(:products, [:title])
   create index(:products, [:inserted_at])
   ```

2. **Use `:flop_opts` to tune pagination** — reduce the default page size to load fewer records at once:

   ```elixir
   @derive {
     Blank.Schema,
     flop_opts: [
       default_limit: 10,
       max_limit: 50
     ],
     fields: [...]
   }
   ```

3. **Preload associations** sparingly. Every association field on the index page generates a JOIN or a separate query. Consider hiding association fields from the index view using `index_fields:` if they aren't needed there.

4. **Watch for N+1 queries** — if your schema has `has_many` associations displayed on the index page, each row may trigger a separate query. Blank uses Ecto preloads internally for `belongs_to` associations, but `has_many` on index pages can be expensive.

### "Export is slow for large datasets"

**Problem:** Clicking export on an index page takes a very long time or times out.

**Solution:** Exports run in the background via `Blank.DownloadAgent` and stream data through the exporter's `process/2` and `save/2` callbacks. The bottleneck is usually in the exporter implementation:

1. **Check for N+1 queries** in your custom exporter's `process/2` callback. It's called once per row — avoid making database calls inside it.
2. **Preload necessary associations** in your schema's query. Blank exports the filtered index query as-is, so make sure your schema preloads what the exporter needs.
3. **Use `flop_opts` to limit the export scope** — consider adding a `max_limit` to your schema defaults or applying heavier filters before exporting.
4. **Ensure your exporter's `save/2` is streaming** — it should write incrementally rather than buffering the entire dataset in memory.

See the [Custom Exporter guide](../howtos/Custom%20Exporter.md) for details on writing efficient exporters.

---

## Where to next

- **[Authentication](Authentication.md)** — configure local login, ueberauth providers, session management, and bootstrapping.
- **[Authorization](Authorization.md)** — write policy modules, configure roles, and use `can?/3` in your own LiveViews.
- **[Role Mappers](Role%20Mappers.md)** — map IdP claims (GitHub teams, OIDC groups) to Blank roles on every login.
- **[Audit Logging](../howtos/Audit%20Logging.md)** — automatic CRUD audit trail, custom events, and the live-streaming viewer.
- **[Custom Exporter](../howtos/Custom%20Exporter.md)** — write your own download exporters (PDF, text, ZIP).
- **[Custom Stats](../howtos/Custom%20Stats.md)** — add summary statistics above the record list.
- **[Configuration](../cheatsheets/Configuration.md)** — complete reference for every config key.
- **[Schema Options](../cheatsheets/Schema%20Options.md)** — all options available in `@derive Blank.Schema`.
- **[AdminPage Options](../cheatsheets/AdminPage%20Options.md)** — all options for `use Blank.AdminPage`.
- **[Field Options](../cheatsheets/Field%20Options.md)** — all field-level options (`searchable`, `sortable`, `viewable`, etc.).
- **[Mix Tasks](../cheatsheets/Mix%20Tasks.md)** — reference for `mix blank.install`, `mix blank.user.new`, and other tasks.
