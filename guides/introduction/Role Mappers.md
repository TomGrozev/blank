# Role Mappers

A Role Mapper converts identity provider (IdP) claims into a list of role atoms
every time an admin logs in through ueberauth. The resulting roles are written
directly to `User.roles`, replacing whatever was there before.

## Overview

On every ueberauth callback — first login and every subsequent login — Blank
invokes your configured role mapper with the full `Ueberauth.Auth` struct. The
mapper returns a plain list of role atoms, and Blank overwrites `User.roles`
with them.

This means your IdP is the source of truth for roles. When an admin is added to
a GitHub team or assigned a group in your OIDC provider, that change takes
effect on their very next login. No manual role management is required.

## Configuring a mapper

Set the mapper in your app config under `:blank, :authorization`:

```elixir
config :blank, :authorization,
  role_mapper: {Blank.Authorization.RoleMappers.GitHub, [team_slug_to_role: %{"payments-team" => :payment_manager}]}
```

The config key accepts two forms:

- **Tuple form with options:** `{Module, opts}` — the mapper receives `opts` as
  a keyword list. Use this when the mapper needs per-provider mapping tables or
  other configuration.

  ```elixir
  config :blank, :authorization,
    role_mapper: {Blank.Authorization.RoleMappers.OIDCC, [groups_to_roles: %{"admin" => :system_admin}]}
  ```

- **Plain module shorthand:** `Module` — equivalent to `{Module, []}`. The
  mapper receives an empty keyword list. Use this for custom mappers that
  hardcode their logic.

  ```elixir
  config :blank, :authorization,
    role_mapper: MyApp.RoleMappers.Custom
  ```

## Built-in mappers

Blank ships two built-in role mappers. Both implement the
`Blank.Authorization.RoleMapper` behaviour.

### GitHub mapper

`Blank.Authorization.RoleMappers.GitHub` reads GitHub team slugs from
`auth.extra.raw_info["teams"]` (populated by a ueberauth GitHub strategy) and
maps them to role atoms.

**Option:** `:team_slug_to_role` — a map of team slug strings to role atoms.

```elixir
config :blank, :authorization,
  role_mapper:
    {Blank.Authorization.RoleMappers.GitHub,
     team_slug_to_role: %{
       "payments-team" => :payment_manager,
       "admins" => :system_admin
     }}
```

**Behaviour details:**

- Team slugs are matched as exact strings against the keys of
  `team_slug_to_role`.
- The returned list is de-duplicated — a user in two teams that map to the same
  role receives that role only once.
- If no teams match (or no teams are present in the auth response), the mapper
  returns `[]`. The caller applies role-floor semantics (`[]` → `[:member]`,
  see below).

### OIDCC mapper

`Blank.Authorization.RoleMappers.OIDCC` reads OIDC group claims from
`auth.extra.raw_info["groups"]` (as populated by the `oidcc` library) and maps
them to role atoms.

**Option:** `:groups_to_roles` — a map of group name strings to role atoms.

```elixir
config :blank, :authorization,
  role_mapper:
    {Blank.Authorization.RoleMappers.OIDCC,
     groups_to_roles: %{
       "admin" => :system_admin,
       "payments" => :payment_manager
     }}
```

**Behaviour details:**

- Group names are matched as exact strings against the keys of
  `groups_to_roles`.
- The returned list is de-duplicated — a user in multiple groups that map to
  the same role receives that role only once.
- If no groups match (or no groups are present), the mapper returns `[]`.

## Role floor semantics

Blank applies a role floor to guarantee every authenticated user has at least
one role. The behaviour depends on what the mapper returns:

| Condition | Resulting `User.roles` |
|---|---|
| No mapper configured | `[:member]` |
| Mapper returns `[]` | `[:member]` (default floor) |
| Mapper returns non-empty list | Exactly that list |

The floor is **`[:member]`** — not `:system_admin`. A user who gets only
`[:member]` can log in but cannot perform any admin actions unless your policy
module explicitly grants them.

**Important:** When the mapper returns a non-empty list, no implicit `:member`
is appended. If the mapper returns `[:payment_manager]`, the user gets
*exactly* `[:payment_manager]`. The mapper author controls the full role set by
returning a non-empty list. If you want `:member` *plus* some other role,
return both atoms explicitly:

```elixir
def map_claims(_auth, _opts), do: [:payment_manager, :member]
```

## Validation

After the mapper returns, Blank validates the role list against the
allowed-set. The allowed-set is the union of:

- Built-in roles: `:system_admin`, `:member`
- Consumer-configured roles from config:

  ```elixir
  config :blank, :authorization,
    roles: [:payment_manager, :org_manager]
  ```

If the mapper returns a role that is **not** in the allowed-set, the login
fails. Blank emits an audit event:

- Event: `accounts.login_failed`
- Reason: `"invalid_roles_from_mapper"`

This protects against misconfigured mappers returning roles that the rest of
the system does not recognise. Every role your mapper might return must be
listed in `config :blank, :authorization, roles: [...]`.

## Writing a custom mapper

When the built-in mappers do not fit your IdP, implement the
`Blank.Authorization.RoleMapper` behaviour:

```elixir
defmodule MyApp.RoleMappers.Custom do
  use Blank.Authorization.RoleMapper

  @impl true
  def map_claims(%Ueberauth.Auth{} = auth, opts) do
    # Read claims from auth.info, auth.extra.raw_info, etc.
    # Map them to role atoms.
    # Return a plain list of atoms.
    case auth.info do
      %{email: "admin@" <> _rest} -> [:system_admin]
      _ -> []
    end
  end
end
```

Then wire it up in config:

```elixir
config :blank, :authorization,
  role_mapper: {MyApp.RoleMappers.Custom, []}
```

**Contract:**

- The `map_claims/2` callback receives the full `Ueberauth.Auth.t()` struct and
  a keyword list of options from config.
- Return a **plain list of role atoms** — no `{:ok, _} | {:error, _}` tuple
  wrapping. A bare list.
- Do not call `Blank.Authorization.validate_roles/1` yourself — the caller
  handles validation.
- You are not responsible for role-floor semantics — the caller applies the
  `[]` → `[:member]` fallback.

**Where to find claims:**

- `auth.info` — the standard ueberauth info map (`email`, `name`, `nickname`,
  `image`).
- `auth.extra.raw_info` — provider-specific raw data (GitHub teams, OIDC
  groups, Google profile data).
- `auth.extra.raw_info.user` — nested payloads from some strategies.

Your mapper runs on *every* login, so keep it fast. Do not make network calls
or perform heavy computation — extract and map from the `Ueberauth.Auth` struct
already available.

## Example: GitHub mapper in action

Here is the full flow when an admin logs in via GitHub with the following
config:

```elixir
config :blank, :authorization,
  roles: [:payment_manager],
  role_mapper:
    {Blank.Authorization.RoleMappers.GitHub,
     team_slug_to_role: %{"payments-team" => :payment_manager}}
```

1. The admin clicks "Sign in with GitHub" and completes the ueberauth flow.
2. GitHub returns an `Ueberauth.Auth` struct with `auth.extra.raw_info["teams"]`
   containing `["payments-team", "design-team"]`.
3. The GitHub mapper reads the teams, matches `"payments-team"` against the
   `team_slug_to_role` map, and finds `:payment_manager`.
4. The mapper returns `[:payment_manager]`. Because this is non-empty, the
   user's `User.roles` is overwritten to `[:payment_manager]` — not
   `[:payment_manager, :member]`.
5. Blank validates `[:payment_manager]` against the allowed-set
   (`[:system_admin, :member, :payment_manager]`) and the login proceeds.
6. On the next `can?/3` call, the policy module sees `:payment_manager` in
   `user.roles` and can grant or deny access accordingly.

## Where to next

- **[Authorization guide](Authorization.md)** — write a policy module that
  checks roles with `can?/3` and grants capabilities per-role.
- **[Schema Options cheatsheet](../cheatsheets/Schema Options.md)** — configure
  how Blank exposes your Ecto schemas.
- **[Configuration cheatsheet](../cheatsheets/Configuration.md)** — the full
  set of `config :blank, :authorization` keys.
