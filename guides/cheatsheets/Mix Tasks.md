# Mix Tasks

Blank ships with two mix tasks: `blank.install` for one-time setup and
`blank.user.new` for creating local users directly in the database.

---

## `mix blank.install`

One-time setup after adding Blank to your application's dependencies.

### What it does

| Step | Description |
|---|---|
| Copies migrations | Copies Blank's migrations from `priv/repo/migrations_<adapter>/` into your app's migrations directory. |
| Updates Tailwind config | Adds a `@source` directive pointing at Blank's `lib/` directory in every `assets/**/app.css` file. |
| Adds audit socket options | Appends `:peer_data`, `:x_headers`, and `:user_agent` to the `connect_info` list in your endpoint's socket configuration. |

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `--adapter` | `ecto_sql` \| `arango` | `ecto_sql` | Database adapter. Controls which migration set is copied. |
| `--migrations_path` | `string` | `priv/repo/migrations` | Custom directory to copy migrations into. Repeatable for multiple paths. |

### Examples

```bash
# Default install (ecto_sql adapter)
mix blank.install

# Install with ArangoDB adapter
mix blank.install --adapter arango

# Custom migrations directory
mix blank.install --migrations_path priv/custom_migrations

# Multiple migration paths (umbrella-friendly)
mix blank.install --migrations_path apps/admin/priv/repo/migrations --migrations_path apps/core/priv/repo/migrations
```

### Umbrella apps

When no `--migrations_path` is given, the task auto-discovers umbrella child apps by
scanning `apps/*/priv/repo/migrations`. Any existing directory is included.

### Post-install

Run `mix ecto.migrate` to apply the copied migrations.

---

## `mix blank.user.new`

Create a local-identity user directly in the `blank_users` table. This is a
break-glass path for bootstrapping when no identity provider is available.

### Options

| Option | Short | Required | Description |
|---|---|---|---|
| `--email` | `-e` | Yes | User's email address. |
| `--password` | `-p` | Yes | User's password. Must satisfy the configured password policy. |
| `--name` | `-n` | No | Display name for the user. |
| `--roles` | — | No | Comma-separated list of role atoms. |
| `--repo` | `-r` | No | Repo module. Defaults to `Application.fetch_env!(:blank, :repo)`. |

### Examples

```bash
# Bootstrap a system admin
mix blank.user.new -e admin@example.com -p "strong-password" --roles system_admin

# User with display name and multiple roles
mix blank.user.new -e user@example.com -p "password" -n "Jane Doe" --roles member,payment_manager

# User with no roles (closed-by-default policy applies)
mix blank.user.new -e guest@example.com -p "password"
```

### Behaviour

- Always creates a **local-identity** user (`provider: nil`, `external_uid: nil`).
- Emits an `accounts.user_created` audit event via `Blank.Audit`.
- Roles are validated against the allowed-set (built-in roles plus any configured via `:blank, :roles`).
- Fails if a user with the given email already exists.
- Starts the repo and application as needed — no running server required.

### Short-form aliases

```bash
# These are equivalent to the long-form examples above
mix blank.user.new -e admin@example.com -p "strong-password" --roles system_admin
mix blank.user.new -e user@example.com -p "password" -n "Jane Doe" --roles member,payment_manager
```

---

## Where to next

- **[Authentication — Bootstrap](/guides/introduction/Authentication.md#bootstrap)** — first-run setup flow that pairs with this task.
- **[Authorization — Roles](/guides/introduction/Authorization.md#roles)** — role system reference, allowed-set validation, and the `:system_admin` break-glass role.
- **[Getting Started](/guides/introduction/Getting%20Started.md)** — full walkthrough from installation to first admin page.
