# Architecture

Blank is a drop-in admin panel for Phoenix applications. It does not generate code into your project — it ships as a library that you configure through Elixir macros and compile-time options. This guide explains how the pieces fit together at a high level, so you can reason about what happens when a request comes in and how the subsystems interact.

---

## Overview

Blank is built on **Phoenix LiveView** with **Ecto** at the persistence layer. Its architecture follows a layered pattern:

| Layer | Responsibility |
|---|---|
| **Routing** | Mounts the admin shell and registers resource pages |
| **AdminPage** | Orchestrates CRUD screens for a single Ecto schema |
| **Schema** | Describes how a database table is presented and validated |
| **Fields** | Renders and validates individual data types |
| **Authorization** | Checks permissions before every action |
| **Audit** | Logs every CRUD operation with PubSub real-time streaming |
| **Exporter** | Generates CSV, QR code, or custom-format downloads |
| **Stats** | Queries and renders summary metrics above record lists |

Each layer is independent — the AdminPage layer consumes schemas and fields, but a field does not know about authorization, and the audit layer does not know about routing.

---

## High-level diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Your Phoenix App                             │
├──────────────────────────────────────────────────────────────────────┤
│  Router                                                                │
│  │                                                                     │
│  ├─ blank_admin "/admin" ─┬─ AdminPage (User)      index / show /     │
│  │                        ├─ AdminPage (Order)      edit  / new  /    │
│  │                        ├─ AdminPage (Product)    import / export    │
│  │                        └─ Built-in pages ── Login, Profile,        │
│  │                                              Settings, Audit       │
│  │                                                                     │
│  └─ Your application routes                                            │
├──────────────────────────────────────────────────────────────────────┤
│  Blank Core                                                           │
│  │                                                                     │
│  ├─ AdminPage behaviour  ── uses ── Schema protocol ── Field component│
│  ├─ Authorization        ── uses ── Policy modules ── Role mappers    │
│  ├─ Audit logging        ── feeds ── LiveView audit stream            │
│  ├─ Exporters            ── CSV, QR code, custom                      │
│  └─ Stats                ── Value, custom query                       │
├──────────────────────────────────────────────────────────────────────┤
│  Phoenix LiveView  /  Ecto  /  Ueberauth  /  Flop                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Routing layer

Two macros in `Blank.Router` wire the admin panel into your Phoenix router.

### `blank_admin`

`blank_admin "/admin"` installs the admin panel **shell** — it is the entry point and scaffolding that every admin panel needs:

- **Authentication routes** — `/admin/log_in` (GET + POST), `/admin/auth/:provider` and callback (Ueberauth), `/admin/log_out` (DELETE)
- **Built-in pages** — Home (dashboard), Profile, Settings, Audit viewer, and the built-in `Blank.Pages.UsersLive` for managing admins
- **Download routes** — `/admin/download`, `/admin/qrcode` for export file downloads
- **A Phoenix pipeline** (`:blank_browser`) that sets up session fetching, CSRF protection, the root layout, current user loading, and audit context initialization
- **Two LiveView sessions**: an unauthenticated one (login page) and an authenticated one (everything else) mounted with `on_mount` hooks for auth enforcement, navigation, and authorization

The built-in pages and routes are **always installed** — they cannot be disabled. After the shell is wired, you declare resource pages inside the `blank_admin` block.

### `admin_page`

`admin_page "/products", MyApp.Admin.ProductsLive` registers a single resource. It generates **7 routes** under the given path:

| Route | LiveAction | Purpose |
|---|---|---|
| `/products/` | `:index` | Paginated list with search, filter, sort |
| `/products/new` | `:new` | Creation form |
| `/products/import` | `:import` | Bulk-import modal (CSV, etc.) |
| `/products/export` | `:export` | Export format selection modal |
| `/products/:id` | `:show` | Detail view |
| `/products/:id/edit` | `:edit` | Edit form |
| `DELETE /log_out` | — | Signs out and redirects to login |

The router also tracks every registered page in `@blank_admin_modules`, which drives the sidebar navigation.

---

## AdminPage layer

`Blank.AdminPage` is the central orchestrator. Every resource page is a **LiveView** created with `use Blank.AdminPage`. The `__using__/1` macro generates a complete LiveView module that:

1. **Implements the `Blank.AdminPage` behaviour** — providing `config/1` and `repo/0` callbacks
2. **Delegates LiveView callbacks** to `Blank.AdminPage` functions — `mount/3`, `handle_params/3`, `handle_event/3`, `handle_async/3`, `handle_info/2`, `render/1`
3. **Imports authorization** via `use Blank.Authorization` — automatically importing `can?/3` and setting the resource type (derived from the schema name)
4. **Stores configuration** — the options passed to `use` (schema, icon, field lists, stats, index buttons) are stored in `@config_opts`

### Lifecycle callbacks

The LiveView callbacks are uniform across all admin pages. Blank handles the following events internally:

| Event | What it does |
|---|---|
| `"validate"` | Decodes form params, runs the changeset, re-renders the form |
| `"save"` | Decodes form params, calls `Context.create/4` or `Context.update/5` |
| `"delete"` | Calls `Context.delete/3` and streams the deletion |
| `"update-filter"` | Rebuilds the Flop query URL and pushes a patch |
| `"toggle-search"` | Switches between simple search and advanced per-field filtering |
| `"idx-btn-click"` | Handles custom index button clicks (patch, navigate, or custom function) |

Any event not handled internally is forwarded to your `admin_hook/3` callback, giving you a safe extension point without overriding generated code.

### Configuration

The `use Blank.AdminPage` macro accepts these key options:

- `:schema` (required) — the Ecto schema module
- `:repo` — the Ecto repo (defaults to the globally configured repo)
- `:icon` — hero icon class for the sidebar
- `:index_fields`, `:show_fields`, `:edit_fields` — which fields appear on each screen
- `:stats` — keyword list of stat definitions (default: a total count)
- `:index_buttons` — override or disable the New / Import / Export buttons

### Layout and rendering

The AdminPage renders three distinct layouts depending on `live_action`:

| live_action | Template | Description |
|---|---|---|
| `:index`, `:import`, `:export` | `admin_index` | Table + filter bar + stats + buttons |
| `:show` | `admin_show` | Read-only detail view |
| `:new` | `admin_edit` (or `render_new`) | Creation form |
| `:edit` | `admin_edit` | Edit form |

If you implement the optional `render_new/1` callback, it overrides the default creation form — useful for wizard-style or multi-step creation flows.

---

## Schema layer

`Blank.Schema` is an **Elixir protocol** that describes how an Ecto schema is displayed, identified, and queried. You attach it to your Ecto schemas via `@derive`:

```elixir
@derive {
  Blank.Schema,
  identity_field: :title,
  order_field: :inserted_at,
  fields: [
    title: [searchable: true, sortable: true],
    price: [],
    category: [display_field: :name]
  ],
  create_changeset: &__MODULE__.create_changeset/2,
  update_changeset: &__MODULE__.update_changeset/2
}
```

### Protocol functions

The protocol defines six functions, all implemented at compile time for each derived schema:

| Function | Purpose |
|---|---|
| `name/1` | Returns the display name of a record (uses `identity_field`) |
| `primary_keys/1` | Returns the primary key atom(s) |
| `changeset/2` | Returns the changeset function for `:new` or `:edit` actions |
| `get_field/2` | Returns the `Blank.Field.t()` definition for a given field atom |
| `identity_field/1` | Returns the field used as the record's display name |
| `order_field/1` | Returns the default sort field and direction |

### Flop.Schema integration

The derive also generates a `Flop.Schema` implementation at compile time. This is how pagination, filtering, and sorting work: the `:searchable` and `:sortable` field options feed into Flop's filterable/sortable lists, and association fields with `:display_field` get compound join fields automatically.

### Field discovery

By default, the derive discovers all schema fields, associations, and virtual fields, then strips foreign keys. You only need to list fields in the derive when you want to override defaults (label, searchable, etc.) or when the field is a virtual field not backed by a database column.

---

## Field layer

Each field in a Blank admin page is rendered by a **LiveComponent** module in `Blank.Fields.*`. Fields handle three rendering contexts:

| Context | Function | Example |
|---|---|---|
| **Display** (show page, table cell) | `render_display/1` | Plain text, formatted date, boolean badge |
| **Form** (new/edit page) | `render_form/1` | Text input, checkbox, datetime picker, select dropdown |
| **Filter** (index filter bar) | `render_filter/1` | Search input, date range |

### Built-in field modules

| Module | Ecto types | Behavior |
|---|---|---|
| `Blank.Fields.Text` | `:string`, `:integer`, `:float`, `:decimal`, fallback | Simple text input |
| `Blank.Fields.Boolean` | `:boolean` | Checkbox toggle |
| `Blank.Fields.DateTime` | `:utc_datetime`, `:naive_datetime` | Datetime picker |
| `Blank.Fields.BelongsTo` | `belongs_to` association | Searchable select dropdown |
| `Blank.Fields.HasMany` | `has_many`, `has_one` | Inline add/remove of related records |
| `Blank.Fields.List` | `{:array, *}` | Tag-style multi-value input |
| `Blank.Fields.Password` | password field | Masked input with reveal toggle |
| `Blank.Fields.Location` | location data | Map-based geolocation picker |
| `Blank.Fields.QRCode` | QR code data | QR code image generator |
| `Blank.Fields.Currency` | `:decimal` with currency | Formatted currency input |

### Field options

Every field accepts a standard set of options defined in `Blank.Field`:

- `:label` — human-readable label (default: humanized field name)
- `:placeholder` — placeholder text in form inputs
- `:searchable` — whether the field appears in the search/filter bar
- `:sortable` — whether the column header is clickable for sorting
- `:viewable` — set to `false` to hide the field entirely from admin views
- `:readonly` — display-only, not editable
- `:display_field` — for associations, which field on the related struct to display
- `:select` — a custom Ecto dynamic for selecting the display value

See [Field Options](../cheatsheets/Field%20Options.md) for the complete reference.

---

## Authentication flow

Blank supports two authentication modes, configured independently:

1. **Local login** — email + password form, controlled by `config :blank, :auth, local_login: :enabled | :disabled`
2. **Ueberauth providers** — Google, GitHub, etc., configured via the standard Ueberauth config

### Login flow

```
User visits /admin/log_in
         │
         ├─ Local login enabled?
         │     ├─ Yes ── Render email + password form
         │     │           POST /admin/log_in
         │     │           │
         │     │           ├─ Valid creds ── Create session token
         │     │           │                   Run role mapper (if configured)
         │     │           │                   Redirect to /admin
         │     │           └─ Invalid ── Re-render with error
         │     │
         │     └─ No ──── Render Ueberauth provider buttons
         │                 Click provider
         │                 │
         │                 ├─ /admin/auth/:provider
         │                 └─ /admin/auth/:provider/callback
         │                       │
         │                       ├─ Success ── Find or create user
         │                       │                Run role mapper
         │                       │                Create session token
         │                       │                Redirect to /admin
         │                       └─ Failure ── Redirect to /admin/log_in with error
         │
Session stored in `blank_users_tokens` table.
```

### Session management

- The session token is stored in `blank_users_tokens` with an expiry
- `Blank.Plugs.Auth.fetch_current_user/2` loads the user on every request from the token
- `Blank.Plugs.Auth.ensure_authenticated/2` (via `on_mount`) halts unauthenticated access to protected routes
- `Blank.Plugs.Auth.redirect_if_user_is_authenticated/2` prevents logged-in users from seeing the login page

---

## Authorization flow

Authorization in Blank is **deny by default** with a break-glass mechanism.

### Coarse-grained authorization (on mount)

Every LiveView mount in the authenticated session runs the `{Blank.Authorization, :authorize}` `on_mount` hook:

1. Read the LiveView module's `@blank_resource_type` (set by `use Blank.Authorization, :key`)
2. Map the `live_action` to a coarse action: `:list` (for index, import, export) or `:read` (for show, edit, new)
3. Call `can?(current_user, coarse_action, %Blank.Scope{resource_type: type})`
4. If denied → halt the socket, flash an error, redirect to `/admin`

Pages that do not declare `@blank_resource_type` (e.g., dashboard, profile, settings) skip this check — they are accessible to any authenticated user.

### Fine-grained authorization (can?/3)

```
can?(user, action, scope)
         │
         ├─ user has :system_admin role?
         │     └─ Yes ── return true (break-glass)
         │
         └─ No ──── delegate to configured policy module
                      policy_module().policy(user, action, scope)
                      │
                      ├─ true  ── action allowed
                      └─ false ── action denied
```

- `user` — the current user struct (must have a `:roles` key with a list of atom roles)
- `action` — an atom like `:list`, `:read`, `:create`, `:update`, `:delete`
- `scope` — a `%Blank.Scope{}` struct with at minimum a `:resource_type` atom

### Configuring authorization

```elixir
config :blank, :authorization,
  roles: [:payment_manager, :content_editor],
  policy_module: MyApp.Policy,
  role_mapper: {MyApp.RoleMapper, []}
```

- **`:roles`** — the complete set of allowed role atoms (validated at boot). Built-in roles `:system_admin` and `:member` are always included.
- **`:policy_module`** — a module implementing a `policy/3` function. Defaults to `Blank.Authorization.DefaultPolicy` (which denies everything).
- **`:role_mapper`** — a module that maps identity provider claims to Blank roles, called during login. See the [Role Mappers](./Role%20Mappers.md) guide.

### Where checks happen

Authorization checks are applied at three levels:

| Level | Location | Check |
|---|---|---|
| **Mount time** | `on_mount` hook in `blank_admin` session | Coarse `:list` / `:read` |
| **Per-action** | Inside `AdminPage` event handlers | `can?/3` is imported into every AdminPage |
| **UI** | `can?/3` calls in templates | Conditionally show/hide buttons and actions |

---

## Audit logging flow

Every CRUD operation through Blank is automatically audited.

### How it works

```
AdminPage performs save / delete
         │
         ├─ Context.create/4 ──── Blank.Audit.log!(ctx, "item.create", params)
         ├─ Context.update/5 ──── Blank.Audit.log!(ctx, "item.update", params)
         └─ Context.delete/3 ──── Blank.Audit.log!(ctx, "item.delete", params)
                  │
                  ├─ Insert row into blank_audit_logs table
                  │     (user_id, action, extra metadata, user_agent, ip)
                  │
                  └─ PubSub.broadcast("audit:logs", {:audit_log, log})
                           │
                           └─ Audit viewer LiveView receives broadcast
                                Updates stream in real-time
```

### Update tracking

For update operations, the audit log captures a **before/after diff**: what the record looked like before the update vs. what changed. This is stored in the `extra` JSONB field of the `blank_audit_logs` table and is visible in the audit viewer.

### Multi-operation audits

When you need an audit log as part of a database transaction, use `Blank.Audit.multi/4` to add an audit step to an `Ecto.Multi`. This ensures the audit entry is only written if the transaction commits.

### PubSub broadcasting

Every audit log insert broadcasts on the `"audit:logs"` topic via `Blank.PubSub`. The built-in audit viewer page (`/admin/audit`) subscribes to this topic and streams new entries in real-time — no polling, no page refresh.

---

## Export flow

Exports allow users to download records in various formats.

### Built-in exporters

| Exporter | Extension | Description |
|---|---|---|
| `Blank.Exporters.CSV` | `.csv` | Comma-separated values |
| `Blank.Exporters.QRCode` | `.zip` | QR code images per record, zipped |

### How an export works

```
User on index page clicks "Export {plural_name}"
         │
         ├─ Push patch to :export live_action
         │     Opens modal: select CSV or QR Code
         │
         ├─ POST (phx-click) with chosen exporter
         │
         ├─ Blank.Exporter.export(exporter, repo, schema, fields)
         │     │
         │     ├─ Stream all records via Context.list_schema/3
         │     ├─ Map each record through exporter.process/2
         │     ├─ Write stream to temp file via exporter.save/2
         │     │     Path: <tmp_dir>/blank/export_<name>_<uuid>.<ext>
         │     │
         │     └─ Register file with Blank.DownloadAgent
         │          Returns download ID
         │
         ├─ Push navigate to /admin/download?id=<uuid>
         │     DownloadAgent serves the file, then schedules cleanup
         │
         └─ File cleaned up after download
```

### Custom exporters

Implement the `Blank.Exporter` behaviour (6 callbacks: `display?/1`, `name/0`, `icon/0`, `ext/0`, `process/2`, `save/2`) and register it in config:

```elixir
config :blank, additional_exporters: [MyApp.CustomExporter]
```

See [Custom Exporter](../howtos/Custom%20Exporter.md) for a full walkthrough.

---

## Stats flow

Stats are summary metrics displayed at the top of the index page, above the record table.

### How stats load

```
AdminPage mount (:index action)
         │
         └─ assign_stats(socket, repo, schema, fields, module)
              │
              ├─ For each stat in module.config(:stats):
              │     │
              │     ├─ Call stat_func(key, base_query, module)
              │     │     │
              │     │     ├─ Returns {:query, query} ── query-based stat
              │     │     └─ Returns {:value, fun}    ── assign-based stat
              │     │
              │     ├─ Value stats evaluated immediately against socket assigns
              │     └─ Query stats collected, then:
              │
              └─ All query stats combined into Ecto.Multi
                   Run in repo.transaction via start_async(:stats)
                   │
                   └─ handle_async(:stats) updates each stat's AsyncResult
```

### Built-in stats

By default, every admin page includes a **total count** stat — it counts all records in the table. You can customize it or add your own via the `:stats` option:

```elixir
use Blank.AdminPage,
  schema: Product,
  stats: [
    total: [],                          # default total count
    in_stock: [name: "Total in-stock"]  # custom stat
  ]
```

Custom stats require a `stat_query/2` callback:

```elixir
@impl Blank.AdminPage
def stat_query(:in_stock, query) do
  {:query, from(p in query, where: p.stock > 0, select: count(p))}
end
```

See [Custom Stats](../howtos/Custom%20Stats.md) for the full behaviour and examples.

---

## Key design decisions

### Drop-in, not a generator

Blank is a **library dependency**, not a code generator. You never copy Blank code into your project. Instead, you configure it through compile-time macros (`@derive`, `use`, `import`) and runtime config. This means:

- **Upgrades are safer** — you update the Hex package, not generated files that may have drifted
- **No lock-in** — your Ecto schemas are unchanged; the `@derive` annotation is purely additive
- **Less surface area** — you write only the modules that actually differ from defaults

### Closed by default

Authorization in Blank starts from a position of **deny everything**. Unless you explicitly configure a policy module that returns `true` for an action, or a user has the `:system_admin` role, access is denied. This is enforced at two levels:

1. **On mount** — unauthorized pages redirect before rendering a single pixel
2. **Per action** — `can?/3` is available in every AdminPage

### Audit everything

All CRUD operations through Blank's `Context` module are automatically audited. You do not need to add audit calls — they are built into `create/4`, `update/5`, and `delete/3`. For update operations, the before/after diff is captured automatically from the changeset.

### Extensible at defined seams

Blank exposes well-defined extension points (Elixir behaviours) rather than asking you to override generated code:

| Extension point | Behaviour | What you implement |
|---|---|---|
| Custom exporter | `Blank.Exporter` | `display?/1`, `name/0`, `icon/0`, `ext/0`, `process/2`, `save/2` |
| Custom stats | `Blank.Stats` | `query/3`, `render/1` |
| Custom field | `Blank.Field` | `render_display/1`, `render_form/1`, `render_filter/1` |
| Policy module | `policy/3` convention | `policy(user, action, scope)` returning boolean |
| Role mapper | convention | Maps IdP claims to Blank role atoms |

### Compile-time configuration

Where possible, Blank shifts work to compile time. The `@derive` annotation generates protocol implementations and `Flop.Schema` implementations for each schema. The `use Blank.AdminPage` macro generates the entire LiveView module with all callbacks wired up. This means:

- **Fast at runtime** — no reflection or dynamic dispatch where static dispatch will do
- **Early errors** — misconfigurations are caught at compile time (via `NimbleOptions` validation)
- **Small runtime footprint** — the OTP application starts only a PubSub, DownloadAgent, and Presence process

---

## Application supervisor

The `Blank.Application` OTP application starts a minimal supervision tree:

```
Blank.Application
├── Phoenix.PubSub (Blank.PubSub)    — Broadcast channel for audit logs
├── Blank.DownloadAgent              — Manages temp export file lifecycle
└── Blank.Presence                   — Tracks active admin users via Phoenix.Presence
```

At boot, it also validates your Ueberauth and authorization configuration, failing fast with clear error messages if something is misconfigured.

---

## Where to next

- **[Getting Started](./Getting%20Started.md)** — Install Blank and wire up your first admin page
- **[Authentication](./Authentication.md)** — Configure local login, Ueberauth providers, and session management
- **[Authorization](./Authorization.md)** — Set up roles, policy modules, and fine-grained access control
- **[Role Mappers](./Role%20Mappers.md)** — Map identity provider claims to Blank roles
- [AdminPage Options cheatsheet](../cheatsheets/AdminPage%20Options.md) — Every option `use Blank.AdminPage` accepts
- [Schema Options cheatsheet](../cheatsheets/Schema%20Options.md) — Every option `@derive Blank.Schema` accepts
- [Field Options cheatsheet](../cheatsheets/Field%20Options.md) — All field-level configuration options
- [Custom Exporter](../howtos/Custom%20Exporter.md) — Build your own export format
- [Custom Stats](../howtos/Custom%20Stats.md) — Add custom metrics to the index page
- [Audit Logging](../howtos/Audit%20Logging.md) — Query, filter, and manage audit logs
- [Routing](../howtos/Routing.md) — Advanced routing scenarios
