# Configuration Quick Reference

Blank uses several config namespaces. This page is the complete reference for every key.

## Core config (`config :blank, ...`)

| Key | Type | Default | Description |
|---|---|---|---|
| `:endpoint` | `module()` | — (required) | Your Phoenix Endpoint module. |
| `:repo` | `module()` | — (required) | Your Ecto Repo module. |
| `:use_local_timezone` | `boolean()` | `false` | Display timestamps in the browser's timezone instead of UTC. |
| `:user_module` | `module()` | `Blank.Accounts.User` | Override the User schema module. |
| `:additional_exporters` | `[module()]` | `[]` | Custom exporter modules to appear in the export dropdown. Each must implement the `Blank.Exporter` behaviour. |
| `:force_ecto_schema` | `boolean()` | `false` | Force Ecto schema even if `ArangoXEcto` is available. Compile-time only. |

## Auth config (`config :blank, :auth, ...`)

| Key | Type | Default | Description |
|---|---|---|---|
| `:local_login` | `:enabled \| :dev_only \| :disabled` | `:enabled` | Controls local (email/password) login. `:dev_only` shows a warning banner in non-dev environments. |
| `:providers` | `map()` | `%{}` | Per-provider display config. Keys are provider atoms, values are maps with an optional `:name` key. |
| `:idle_timeout` | `{integer(), :minutes \| :hours \| :days}` | `{4, :hours}` | How long a session can remain idle before the user is logged out. |
| `:absolute_lifetime` | `{integer(), :minutes \| :hours \| :days}` | `{60, :days}` | Maximum lifespan of a session regardless of activity. |

## Authorization config (`config :blank, :authorization, ...`)

| Key | Type | Default | Description |
|---|---|---|---|
| `:roles` | `[atom()]` | `[]` | Custom role vocabulary. The built-in roles `:system_admin` and `:member` are always included. Must be a list of atoms. |
| `:policy_module` | `module()` | `Blank.Authorization.DefaultPolicy` | Your authorization policy module. Must implement a `policy/3` callback. |
| `:role_mapper` | `module() \| {module(), keyword()}` | `nil` | Maps IdP claims to roles on login. Plain module is shorthand for `{module, []}`. |

## Ueberauth config (`config :ueberauth, Ueberauth, ...`)

| Key | Type | Default | Description |
|---|---|---|---|
| `:providers` | `keyword()` | — (required if local_login is `:disabled`) | Ueberauth strategy providers. Example: `[github: {Ueberauth.Strategy.Github, []}]`. |

Blank overrides the ueberauth base path inside `blank_admin` routing — you do not need to set `:base_path`.

## Example: full config

```elixir
# In config/config.exs or runtime.exs
config :blank,
  endpoint: MyAppWeb.Endpoint,
  repo: MyApp.Repo,
  use_local_timezone: true,
  additional_exporters: [MyApp.Exporters.PDFExporter]

config :blank, :auth,
  local_login: :dev_only,
  providers: %{github: %{name: "GitHub"}},
  idle_timeout: {2, :hours},
  absolute_lifetime: {30, :days}

config :blank, :authorization,
  roles: [:payment_manager, :content_editor],
  policy_module: MyApp.Policy,
  role_mapper: {Blank.Authorization.RoleMappers.GitHub,
                [team_slug_to_role: %{"payments-team" => :payment_manager}]}

config :ueberauth, Ueberauth,
  providers: [github: {Ueberauth.Strategy.Github, []}]
```

## Boot-time validation

Blank validates config at application start. Invalid config raises at boot:

| Condition | Behaviour |
|---|---|
| `:endpoint` or `:repo` not set | Compile-time error via `fetch_env!` |
| `:roles` is not a list of atoms | Boot-time `raise` |
| `:local_login` is `:disabled` with no ueberauth providers | Boot-time `raise` |
| Invalid role returned from a role mapper | Login failure (runtime, not boot failure) |
