# Authorization

Blank ships a role-based authorization layer. Every operation in the admin panel — viewing a list, creating a record, deleting a resource — passes through a single seam: `Blank.Authorization.can?/3`. You define *who* can do *what* inside *which scope* by writing a policy module.

This guide covers the authorization model, the built-in roles, how to write a policy module, and how scopes and actions fit together.

## Overview

Blank's authorization has three moving parts:

1. **Roles** — atoms attached to each Admin (e.g. `:system_admin`, `:member`, `:payment_manager`). Roles are the unit of capability.
2. **Policy modules** — consumer-supplied modules implementing `Blank.Authorization.Policy`. They decide per `{user, action, scope}` triple whether an operation is allowed.
3. **Scopes** — `Blank.Scope` structs that encode *what kind of thing* is being acted on, which specific record, and any extra dimensional bounds.

The wrapper function `Blank.Authorization.can?/3` ties them together:

```elixir
Blank.Authorization.can?(admin, :create, %Blank.Scope{resource_type: :order})
# => true or false
```

Every call to `can?/3` first checks for the **break-glass** `:system_admin` role. If the Admin holds it, the call short-circuits to `true`. Otherwise, it dispatches to your configured policy module.

## Roles

### Built-in roles

Two roles are always present, regardless of configuration:

| Role | Meaning |
|---|---|
| `:system_admin` | Break-glass. Always permitted — `can?/3` returns `true` before the policy module is consulted. |
| `:member` | Default floor. Every authenticated Admin gets at least this role. Alone it grants no permissions — you opt in explicitly by writing policy clauses for `:member`. |

### Custom roles

Declare additional roles in your application config:

```elixir
# config/config.exs
config :blank, :authorization,
  roles: [:payment_manager, :content_editor, :org_manager]
```

The allowed-set is computed at app boot as the union of the built-in roles and your configured list, then cached for the lifetime of the application.

### Representation

Roles are **atoms in memory**, persisted as **strings in the database**. The `Blank.Types.Role` custom Ecto type handles the conversion transparently. Your `User.roles` column stays `{:array, :string}` in the database — no migration needed.

When you read an Admin's roles in memory, they are always atoms:

```elixir
admin = Blank.Accounts.get_user!(some_id)
admin.roles
# => [:system_admin, :member]
```

### Boot-time validation

Blank validates your role configuration at app boot. Every role in `config :blank, :authorization, roles: [...]` must be an atom. An invalid config raises immediately:

```elixir
# Bad — this raises at boot:
config :blank, :authorization, roles: ["payment_manager"]
```

Use atoms:

```elixir
# Good:
config :blank, :authorization, roles: [:payment_manager]
```

## The break-glass `:system_admin`

`:system_admin` is the emergency override. The `can?/3` wrapper checks for it *before* dispatching to any policy module:

```elixir
# lib/blank/authorization.ex (conceptual)
def can?(user, action, scope) do
  if :system_admin in List.wrap(user.roles) do
    true
  else
    policy_module().policy(user, action, scope)
  end
end
```

Three important consequences:

1. **Your policy module never sees `:system_admin` cases.** You do not need to write `:system_admin in roles` clauses anywhere in your policy. The wrapper handles it.
2. **You cannot accidentally lock out `:system_admin`.** No matter what your policy returns, a `:system_admin` Admin can always perform any action.
3. **It is the only role with blanket permissions.** `:member` and all custom roles start with zero permissions until you grant them in your policy.

### Bootstrap

Create the first `:system_admin` Admin from the shell:

```bash
mix blank.user.new -e admin@example.com -p "SecurePass123!" -n "Admin User" --roles system_admin
```

This is the only bootstrap mechanism. There is no runtime env-var-based backdoor — shell access is the trust boundary for the initial `:system_admin` grant.

> **Note:** If your deployment shape does not have shell access, run the mix task before the runtime starts serving traffic.

## Writing a policy module

A policy module is a consumer module that implements the `Blank.Authorization.Policy` behaviour. It defines `policy/3` clauses matching `{user, action, scope}` triples.

### The `use` macro

Start with `use Blank.Authorization.Policy`. This injects:

- The `@behaviour Blank.Authorization.Policy` declaration
- A catch-all `policy/3` clause that delegates to `Blank.Authorization.DefaultPolicy` (returns `false`)
- A `defoverridable` so your own clauses take precedence

```elixir
defmodule MyApp.Policy do
  use Blank.Authorization.Policy

  # Your clauses here...
end
```

### Defining policy clauses

Each `policy/3` clause receives the Admin struct, an action atom, and a `Blank.Scope` struct. Return `true` to allow, `false` to deny.

Pattern-match on the scope's `resource_type` and the Admin's `roles`:

```elixir
defmodule MyApp.Policy do
  use Blank.Authorization.Policy

  # Members and order managers can read orders
  def policy(%{roles: roles}, :read, %{resource_type: :order}),
    do: :member in roles or :order_manager in roles

  # Only order managers can create, update, or delete orders
  def policy(%{roles: roles}, action, %{resource_type: :order})
      when action in [:create, :update, :delete],
    do: :order_manager in roles

  # Content editors can read and update articles
  def policy(%{roles: roles}, action, %{resource_type: :article})
      when action in [:read, :update],
    do: :content_editor in roles
end
```

Clauses are matched top-to-bottom. The catch-all (inherited from `use Blank.Authorization.Policy`) returns `false` for everything you do not explicitly allow.

### Configuring the policy module

Wire your policy module in config:

```elixir
# config/config.exs
config :blank, :authorization,
  policy_module: MyApp.Policy
```

If `:policy_module` is not set, `can?/3` dispatches to `Blank.Authorization.DefaultPolicy` — meaning only `:system_admin` can do anything. This is the default out-of-the-box posture.

### Using `can?/3` in your own LiveViews

For LiveViews that are not AdminPages, declare the resource type:

```elixir
defmodule MyAppWeb.SomeCustomLive do
  use MyAppWeb, :live_view
  use Blank.Authorization, :order  # declares resource_type for coarse mount check

  # ...
end
```

This wires the `on_mount` hook so the LiveView performs a coarse `:list` / `:read` check at mount time, and imports `can?/3` unqualified so you can add fine-grained checks in handlers:

```elixir
def handle_event("archive", _params, socket) do
  if can?(socket.assigns.current_user, :update, %Blank.Scope{
    resource_type: :order,
    resource_id: socket.assigns.order.id
  }) do
    # proceed...
  else
    {:noreply, put_flash(socket, :error, "Not authorized")}
  end
end
```

AdminPage LiveViews get the resource type automatically from their `schema:` / `key:` config — no manual `use Blank.Authorization` needed.

## DefaultPolicy — closed by default

`Blank.Authorization.DefaultPolicy` is the fallback when no `:policy_module` is configured:

```elixir
defmodule Blank.Authorization.DefaultPolicy do
  def policy(_user, _action, _scope), do: false
end
```

This means the admin panel is **locked for non-`:system_admin` Admins** until you configure a policy module. This is an intentional security posture: operators must explicitly opt in to every permission.

In development, the quickest path to a working panel is:

1. Bootstrap a `:system_admin` Admin with the mix task
2. Log in as that Admin — you can now use every page
3. Later, write and configure a policy module to open specific pages to other roles

## Scopes

A `Blank.Scope` struct tells `can?/3` what is being acted on:

```elixir
%Blank.Scope{
  resource_type: :order,        # required atom — what kind of thing
  resource_id: 42,              # optional — which specific record
  extra: %{org_id: 7}           # optional — consumer escape hatch (defaults to %{})
}
```

### `resource_type` (required)

An atom identifying the resource category — `:order`, `:user`, `:article`, `:audit_log`. This is the primary dimension your policy module matches on.

### `resource_id` (optional)

Use for resource-specific checks, e.g. "can this Admin read *this specific* order?" The policy module has access to the ID and can perform database lookups or ownership checks:

```elixir
def policy(%{id: user_id} = _user, :read, %{resource_type: :order, resource_id: order_id})
    when not is_nil(order_id) do
  # Check if this user owns this specific order
  order = MyApp.Orders.get_order!(order_id)
  order.user_id == user_id
end
```

### `extra` (optional)

An arbitrary map for consumer-specific dimensional bounds — organization membership, event scoping, customer groupings:

```elixir
%Blank.Scope{
  resource_type: :order,
  extra: %{bound_org_ids: [7, 12], bound_event_id: 3}
}
```

Your policy module reads `scope.extra` and applies whatever domain logic makes sense. Blank never interprets the contents of `extra` — it is your escape hatch.

### Constructing scopes in practice

Blank's built-in `on_mount` hook constructs scopes with `resource_type` only (coarse gate). For fine-grained checks inside handlers, you build the scope with `resource_id` and `extra` as needed.

## Actions

Actions are **bare atoms** passed as the second argument to `can?/3`:

```elixir
can?(admin, :create, scope)
can?(admin, :read,   scope)
can?(admin, :update, scope)
can?(admin, :delete, scope)
can?(admin, :list,   scope)
can?(admin, :show,   scope)
```

The CRUD set (`:create`, `:read`, `:update`, `:delete`) covers mutations. The display set (`:list`, `:show`) covers read-only views. You are free to define custom action atoms in your own policy module — `:export`, `:approve`, `:archive`, whatever your domain needs.

The **resource** being acted on lives in the scope, not in the action. `:create` means "create something within this scope" — the scope's `resource_type` tells you what kind of thing. This keeps the action vocabulary small and the policy-matching straightforward.

### Coarse vs. fine-grained

Blank applies a **belt-and-suspenders** approach:

1. **Coarse gate** — the `on_mount` hook runs `can?/3` at mount time with `:list` for index routes and `:read` for show routes. If it fails, the Admin is redirected before the LiveView mounts.
2. **Fine gate** — inside handlers, you call `can?/3` explicitly with the specific action and scope. This catches cases the coarse gate cannot (e.g. "can this Admin *delete* a specific record?").

## `validate_roles/1`

`Blank.Authorization.validate_roles/1` checks that every role in a list is in the allowed-set:

```elixir
Blank.Authorization.validate_roles([:system_admin, :member])
# => :ok

Blank.Authorization.validate_roles([:system_admin, :unknown_role])
# => {:error, [:unknown_role]}
```

This function is called on every role-write path — the mix task, the IdP claim-reader, and any programmatic role update. The `Blank.Types.Role` Ecto type also enforces the allowed-set at cast time, so `validate_roles/1` acts as a redundant fail-safe when a caller bypasses changeset casting.

You normally do not need to call this yourself unless you are writing custom role-update logic outside Blank's built-in paths.

## Where to next?

- **Role Mappers** — map IdP claims (GitHub teams, OIDC groups) to Blank roles on every login. See the Role Mappers guide for `Blank.Authorization.RoleMapper` and the built-in GitHub and OIDCC mappers.
- **`Blank.Authorization`** — module docs for the full API including `allowed_roles/0`, `policy_module/0`, and the `on_mount` hook details.
- **`Blank.Scope`** — module docs for the Scope struct.
- **`Blank.Authorization.Policy`** — behaviour docs for the `policy/3` callback contract.
- **`guides/cheatsheets/Configuration.md`** — all authorization-related config keys at a glance.
