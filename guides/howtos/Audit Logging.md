# Audit Logging

Blank ships a built-in audit logging system that records every mutation in the admin panel and gives you a live-streaming viewer. This guide covers automatic AdminPage logging, custom audit events, querying, and the audit log viewer.

## Overview

Three layers work together:

1. **Automatic logging** — every AdminPage create, update, and delete operation emits an audit entry with the acting Admin, resource type, resource ID, and changed fields. No configuration required.
2. **Custom logging** — use `Blank.Audit.log!/3` or `Blank.Audit.multi/4` to emit your own audit events from anywhere in your app.
3. **Live viewer** — a built-in page at `/admin/audit` that streams new entries in real time via PubSub, with filtering and full metadata inspection.

Every audit entry is an `%Blank.Audit.AuditLog{}` struct persisted to the `blank_audit_logs` table. Fields include:

| Field | Type | Description |
|---|---|---|
| `action` | `string` | The event name (e.g. `"posts.create"`, `"app.send_email"`) |
| `ip_address` | `Blank.Types.IP` | The Admin's IP address at request time |
| `user_agent` | `string` | The browser user agent (or `"SYSTEM"` for automated logs) |
| `params` | `map` | Contextual data about the event |
| `extra` | `map` | Before/after snapshots for changeset-based audit entries |
| `actor_display_name` | `string` | The Admin's display name at the time of the event |
| `actor_email` | `string` | The Admin's email at the time of the event |
| `user` | `belongs_to` | The acting Admin (preloaded by query functions) |
| `inserted_at` | `DateTime` | When the event occurred |

## Prerequisite: the Audit Context

The `audit_context` is the common thread that connects every audit entry to the acting Admin. It is a pre-populated `%Blank.Audit.AuditLog{}` struct with the `user`, `ip_address`, `user_agent`, `actor_display_name`, and `actor_email` fields already filled in from the current request.

Blank's router automatically wires `Blank.Audit.Context` into every admin route as a plug (for standard HTTP) and an `on_mount` hook (for LiveView sessions). This means every AdminPage handler already has `audit_context` in its assigns — you do not need to build it yourself inside admin pages.

If you want audit context available in your own app routes (so you can call `log!/3` from non-admin pages), add the plug to your router:

```elixir
# lib/my_app_web/router.ex
import Blank.Audit.Context

pipeline :browser do
  # ... other plugs ...
  plug :fetch_current_user     # must come before fetch_audit_context
  plug :fetch_audit_context
end

live_session :default,
  on_mount: [
    # ... other hooks ...
    Blank.Audit.Context
  ] do
  # ...
end
```

> **Order matters.** The audit context plug reads `current_user` from conn/socket assigns, so it must appear *after* your authentication plug. Otherwise the audit context will have no user.

For system-level events (background jobs, cron tasks, automated processes) where there is no acting Admin, use `Blank.Audit.AuditLog.system/0`:

```elixir
audit_context = Blank.Audit.AuditLog.system()
# => %AuditLog{user: nil, user_agent: "SYSTEM", extra: %{}}
```

## Automatic audit logging

Every AdminPage create, update, and delete operation is automatically audited. Blank wraps each mutation in an `Ecto.Multi` and appends an audit step via `Blank.Audit.multi/4`. You do not need to opt in — it happens for every `use Blank.AdminPage` module.

### Event names

The action string follows the pattern `{resource_type}.{action}` where `resource_type` is the Phoenix resource name of the schema (e.g. `"posts"` for a `Post` schema) and `action` is one of:

| Operation | Action string | `params` |
|---|---|---|
| Create | `"posts.create"` | `%{item_id: <id>}` |
| Create multiple | `"posts.create_multiple"` | `%{item_ids: [<id>, ...]}` |
| Update | `"posts.update"` | `%{item_id: <id>}` |
| Update multiple | `"posts.update_multiple"` | `%{item_ids: [<id>, ...]}` |
| Delete | `"posts.delete"` | `%{item_id: <id>}` |
| Delete all | `"posts.delete_all"` | `%{}` |

The `item_id` is recorded so the viewer can reconstruct what was acted on, even if the record is later deleted.

### What is captured

Each automatic entry captures:
- **`user`** — the acting Admin (from `socket.assigns.audit_context`)
- **`action`** — the event name described above
- **`params`** — the `item_id` or `item_ids`
- **`ip_address`** — the Admin's IP (from the Plug connection or LiveView peer data)
- **`actor_display_name`** and **`actor_email`** — snapshot of the Admin's identity at event time
- **`inserted_at`** — server timestamp

The `extra` field is not populated by automatic CRUD logging (it is reserved for changeset-based `multi/4` calls — see the Custom Events section below).

### Where the wiring lives

The automatic audit step is in `Blank.Context`, which is called by `Blank.AdminPage` for every `"save"` and `"delete"` event. For example, `Context.create/4` wraps the insert in an `Ecto.Multi` and appends:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:item, changeset)
|> Audit.multi(audit_context, "posts.create", fn audit_context, %{item: item} ->
  %{audit_context | params: %{item_id: item.id}}
end)
|> repo.transaction()
```

Because the audit step is inside the same `Ecto.Multi` transaction, an audit entry is only written if the mutation succeeds. If the changeset is invalid, nothing is recorded.

## Custom audit events

Use `Blank.Audit.log!/3` for one-off events and `Blank.Audit.multi/4` for batch events inside an `Ecto.Multi` transaction.

### One-off events with `log!/3`

```elixir
defmodule MyApp.Orders do
  alias Blank.Audit

  def ship_order(audit_context, order) do
    # ... ship the order ...

    Audit.log!(audit_context, "app.order_shipped", %{
      order_id: order.id,
      tracking_number: "ABC123",
      shipped_at: DateTime.utc_now()
    })
  end
end
```

`log!/3` takes three arguments:
- `audit_context` — a `%Blank.Audit.AuditLog{}` struct (from socket assigns, conn assigns, or `AuditLog.system/0`)
- `action` — a string identifying the event (see action naming below)
- `params` — a freeform map of contextual data

It inserts the record immediately, raises on failure, and broadcasts the entry via PubSub so the live viewer updates in real time.

### Batch events with `multi/4`

When you need atomicity — the audit entry must only be written if the data mutation succeeds — use `multi/4` inside an `Ecto.Multi`:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.update_all(:orders, ...)
|> Blank.Audit.multi(audit_context, "app.bulk_shipped", %{count: 10})
|> MyApp.Repo.transaction()
```

`multi/4` appends an audit step to the multi. It supports three forms for the fourth argument:

**A map** — the params are stored directly:

```elixir
|> Audit.multi(audit_context, "app.bulk_closed", %{count: 42})
```

**A function** — receives the audit context and the multi results so far, and must return an updated `AuditLog` struct:

```elixir
|> Audit.multi(audit_context, "app.order_shipped", fn audit_ctx, %{order: order} ->
  %{audit_ctx | params: %{order_id: order.id, tracking_number: "ABC123"}}
end)
```

**An `Ecto.Changeset`** — Blank computes before/after snapshots and stores them in the `extra` field:

```elixir
changeset = Ecto.Changeset.change(existing_order, %{status: :shipped})

Ecto.Multi.new()
|> Ecto.Multi.update(:order, changeset)
|> Audit.multi(audit_context, "app.status_change", changeset)
|> Repo.transaction()
```

The resulting audit entry will have `extra.before` (the original field values, excluding meta fields) and `extra.after` (only the fields that changed). Fields that did not change are omitted from `after`.

### Action naming conventions

| Prefix | Meaning | Validation |
|---|---|---|
| `app.` | Your custom event (e.g. `"app.send_email"`) | None — any params are accepted |
| `accounts.` | Built-in account events (`login`, `logout`, `user_created`, `roles_updated`) | Validated against expected keys |
| `*.<action>` | Wildcard for CRUD operations (e.g. `"*.create"`, `"*.delete"`, `"*.delete_all"`) | Validated against expected keys |

Custom actions **must** use the `app.` prefix. The built-in actions and wildcards validate that `params` contains exactly the expected keys and will raise `Blank.Audit.AuditLog.InvalidParameterError` if keys are missing or extra.

## Querying audit logs

### `Blank.Audit.list_all/1`

Returns all audit entries in reverse chronological order, newest first. Preloads the `user` association.

```elixir
# Latest 50 entries (default limit)
Blank.Audit.list_all()

# Filter by resource type
Blank.Audit.list_all(where: [action: "posts.create"])

# Custom limit
Blank.Audit.list_all(limit: 10)

# Combined
Blank.Audit.list_all(where: [action: "orders.update"], limit: 25)
```

| Option | Type | Default | Description |
|---|---|---|---|
| `:where` | keyword list | `[]` | Ecto where clauses to filter results |
| `:limit` | integer | `50` | Maximum number of entries to return |

### `Blank.Audit.list_all_for_user/2`

Returns audit entries for a specific Admin. Accepts a user struct or a user ID.

```elixir
# By struct
Blank.Audit.list_all_for_user(current_user)

# By ID
Blank.Audit.list_all_for_user("usr_abc123")

# With options
Blank.Audit.list_all_for_user(user, where: [action: "posts.delete"], limit: 20)
```

The accepted options are the same as `list_all/1`.

### `Blank.Audit.list_all_from_system/1`

Returns audit entries created by the system — logs with no associated user and a user agent of `"SYSTEM"`. Use this to query the audit trail of background jobs and automated processes.

```elixir
# All system entries
Blank.Audit.list_all_from_system()

# Filtered
Blank.Audit.list_all_from_system(where: [action: "app.nightly_sync"])
```

### `Blank.Audit.delete_all/1`

Deletes all audit logs. For accountability, it also inserts a final audit entry recording who performed the deletion.

```elixir
Blank.Audit.delete_all(socket.assigns.audit_context)
# => {:ok, count}
```

This is called from the Settings page in the admin panel (`Blank.Pages.SettingsLive`).

## The audit log viewer

Blank ships a live-streaming audit log viewer at `/admin/audit`. It is a `Blank.Pages.AuditLogLive` LiveView that delegates rendering to `Blank.Components.AuditLogComponent`.

### Live streaming

When the component mounts, it subscribes to the `"audit:logs"` PubSub topic. Every call to `log!/3` or `multi/4` broadcasts `{:audit_log, log}` on this topic. The component receives the broadcast and streams the new entry to the top of the timeline — no page refresh needed.

### What you see

Each entry in the timeline shows:

- **Colour-coded icon** — create (blue), update (sky), delete (rose), accounts (emerald), custom (gray)
- **Human-readable text** — describes what happened, e.g. *"Jane Smith (user) created a Post (ID: 42)"*
- **Linked Admin name** — clicking the name navigates to that Admin's show page (if a schema link is available)
- **Timestamp** — formatted in the viewer's local time zone
- **User agent** and **IP address** — visible when you expand the entry (click the summary)

### Built-in event rendering

The component has dedicated rendering clauses for built-in events:

| Action pattern | Example rendered text |
|---|---|
| `accounts.login` | *"Jane Smith (user) logged in via GitHub"* |
| `accounts.login_failed` | *"Jane Smith failed login for a@b.com (reason: invalid password)"* |
| `accounts.logout` | *"Jane Smith (user) logged out"* |
| `accounts.user_created` | *"Jane Smith (user) created a user"* |
| `*.create` | *"Jane Smith (user) created a Post (ID: 42)"* |
| `*.update` | *"Jane Smith (user) updated a Post (ID: 42)"* |
| `*.delete` | *"Jane Smith (user) deleted a Post (ID: 42)"* |
| `*.delete_all` | *"Jane Smith (user) deleted all Posts"* |

Custom `app.` events fall through to a generic rendering that shows the action string as-is.

### System logs

Entries with `user_agent: "SYSTEM"` and no user appear as *"SYSTEM (system)"* with no link. This covers events from `AuditLog.system/0` — background jobs, cron tasks, and automated processes.

## Example: logging a custom event

Here is a complete example of logging a custom `app.order_shipped` event from a context module:

```elixir
defmodule MyApp.Orders do
  alias Blank.Audit
  alias MyApp.Repo

  def ship_order(audit_context, order) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:order, Ecto.Changeset.change(order, status: :shipped))
    |> Audit.multi(audit_context, "app.order_shipped", fn audit_ctx, %{order: updated} ->
      %{audit_ctx | params: %{order_id: updated.id, tracking_number: "ABC123"}}
    end)
    |> Repo.transaction()
  end
end
```

Call it from a LiveView handler where `audit_context` is already in assigns:

```elixir
def handle_event("ship", %{"id" => id}, socket) do
  order = Orders.get_order!(id)

  case Orders.ship_order(socket.assigns.audit_context, order) do
    {:ok, _} ->
      {:noreply, put_flash(socket, :info, "Order shipped")}

    {:error, _, changeset, _} ->
      {:noreply, put_flash(socket, :error, "Failed to ship order")}
  end
end
```

## Where to next

- **Authorization** — control who can view the audit log and manage settings. The audit log page is a system-level page; configure your policy module to gate access. See the [Authorization guide](../introduction/Authorization.md).
- **Role Mappers** — map IdP claims to Blank roles on every login. Account-level audit events (`accounts.*`) capture role changes automatically. See the [Role Mappers guide](../introduction/Role%20Mappers.md).
- **Custom Exporter** — export audit logs alongside your application data. See the [Custom Exporter guide](Custom%20Exporter.md).
- **`Blank.Audit`** — module docs for the full API.
- **`Blank.Audit.Context`** — module docs for the audit context plug and `on_mount` hook.
- **`Blank.Audit.AuditLog`** — module docs for the Ecto schema and action validation.
