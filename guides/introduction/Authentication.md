# Authentication

Blank uses a single `blank_users` table to store every identity that can log into the admin panel — local email/password accounts and ueberauth-based identity provider (IdP) accounts coexist in the same table. Every audit log entry points at this table through a single `user_id` foreign key, so no matter how an Admin authenticates, their actions are tracked in one place.

This guide covers configuring local login, wiring up ueberauth providers, understanding the unified User model, and bootstrapping your first Admin.

## Local Login

Local login is controlled by a single config key:

```elixir
config :blank, :auth, local_login: :enabled
```

Blank supports three modes:

| Mode | Behaviour |
|---|---|
| `:enabled` | Local login is always available. This is the default. |
| `:dev_only` | Local login is available only in `:dev` and `:test` environments. Blank prints a warning if the app boots in `:prod` with this setting — Admins must use an IdP in production. |
| `:disabled` | Local login is never available. No local login form is rendered, and no local password authentication is accepted. |

**When to use each mode:**

- **`:enabled`** — development, staging, or any deployment where Admins log in with email and password. Also the default, so you can get started without any ueberauth configuration.
- **`:dev_only`** — you are actively integrating an IdP for production but want local login available during development and testing. This prevents local-login drift in `runtime.exs` and makes it obvious when the gate is open.
- **`:disabled`** — production deployments where all authentication must flow through an IdP. Local password login is completely removed from the login page and the server rejects any attempt.

## Ueberauth Provider Setup

Blank installs ueberauth request (`/auth/:provider`) and callback (`/auth/:provider/callback`) routes automatically inside the `blank_admin` router macro — you do not need to add them yourself. You only need to configure the providers.

The host app configures ueberauth per the [ueberauth documentation](https://hexdocs.pm/ueberauth). Add the strategy dependency to `mix.exs` and configure the provider:

```elixir
# mix.exs
defp deps do
  [
    {:ueberauth_github, "~> 0.8"}
  ]
end
```

```elixir
# config/runtime.exs
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.fetch_env!("GITHUB_CLIENT_ID"),
  client_secret: System.fetch_env!("GITHUB_CLIENT_SECRET")
```

That's it — the provider buttons appear on the login page automatically. Blank introspects `Application.get_env(:ueberauth, Ueberauth)[:providers]` to discover configured providers at render time.

Blank is provider-agnostic. It never references a specific strategy module in its own library code. Any ueberauth strategy (Google, GitHub, Auth0, OIDC via `ueberauth_oidcc`, or a custom strategy) works the same way.

## Provider Display Names

By default, Blank derives button labels from the provider atom using `Phoenix.Naming.humanize/1` — `:github` becomes "GitHub", `:google` becomes "Google", and so on. To customize the display name, use Blank's provider config namespace:

```elixir
config :blank, :auth,
  providers: %{
    github: %{name: "GitHub Enterprise"},
    okta: %{name: "Corporate SSO"}
  }
```

This only affects the button label on the login page and the provider name shown on the Profile page. The ueberauth config namespace (under `:ueberauth`) and Blank's provider config namespace (under `:blank, :auth`) are separate — the provider atom is the key that links them.

## Boot-Time Guard

Blank validates your authentication configuration at boot. If local login is disabled AND no ueberauth providers are configured, `Blank.Application.start/1` raises with an actionable message:

```
Blank requires at least one Ueberauth provider to be configured when local auth is disabled.
Please add providers to your Ueberauth config:

    config :ueberauth, Ueberauth,
      providers: [google: {Ueberauth.Strategy.Google, []}]

Or enable local auth:

    config :blank, :auth, local_login: :enabled
```

This catches misconfiguration at deploy time, not at first login. The login page also independently checks at render time and shows an "Authentication methods are not configured" message if both local login and all ueberauth providers are absent — covering runtime config changes that slip past the boot check.

## The Unified User Model

Every identity that logs into Blank — whether through email/password or through an IdP — is a row in `blank_users`. The table fields reveal which kind of identity each row represents:

| Field | Local user | Ueberauth user |
|---|---|---|
| `email` | set | set |
| `name` | optional | set from IdP claims |
| `hashed_password` | Bcrypt hash | `nil` |
| `provider` | `nil` | strategy atom as string (`"github"`, `"google"`) |
| `external_uid` | `nil` | IdP-side unique identifier |
| `roles` | array of atoms | array of atoms |

The table has two unique indexes to enforce identity constraints:

1. **`(provider, external_uid)`** — prevents duplicate IdP identities for the same provider.
2. **`email` filtered to `provider IS NULL`** — ensures local emails are unique, but the same email address can appear from multiple IdP rows.

Email and name are mutable display fields refreshed on every IdP login. They are never identity keys — the composite `(provider, external_uid)` is the external identity key, and the surrogate `id` is the foreign key target for audit logs.

### Password Validation (Local Users)

Local passwords must satisfy Blank's password policy, enforced by the registration and password-change changesets:

- Minimum 12 characters, maximum 72
- At least one lowercase letter
- At least one uppercase letter
- At least one digit or punctuation character (`!?@#$%^&*_0-9`)

Passwords are hashed with Bcrypt before storage. The `hashed_password` column is never exposed through the admin UI.

## Login Page

The login page at `/admin/log_in` is a unified chooser. When local login is enabled, Admins see the email/password form with a "Keep me logged in" checkbox and a "Sign in with …" button for each configured ueberauth provider, separated by an "— or —" divider. When local login is disabled, only the provider buttons are shown.

Clicking a provider button navigates to `/admin/auth/:provider`, which initiates the ueberauth OAuth flow. On return, the callback controller looks up or creates the User and logs them in.

### Login Audit Trail

Every successful login emits an `accounts.login` audit entry recording the email, identity type (`"local"` or `"ueberauth"`), and provider. Failed logins — whether wrong password or IdP failure — emit `accounts.login_failed` with the reason.

## Profile Page

The Profile page at `/admin/profile` renders conditionally based on how the Admin authenticates:

**Local users** see a password-change form with three fields: current password, new password, and password confirmation. Changing the password invalidates all existing sessions (including other devices) by deleting every token for that user, then re-authenticates the current session.

**Ueberauth users** see a read-only identity card showing provider name, external ID, email, and name. A notice below the card reads: "Your account is managed by *ProviderName*. Password changes must be made through your identity provider." There is no password-change form for ueberauth users — the `hashed_password` column is `nil`.

Blank determines whether an Admin is an IdP user by checking `user.provider` — if it is a non-empty string, the profile renders the IdP card.

## Session Management

Blank manages sessions through the `blank_users_tokens` table. When an Admin logs in:

1. A cryptographically random token is generated and stored as a row in `blank_users_tokens` with `context: "session"`.
2. The token is placed in the session and, if the Admin checked "Keep me logged in", in a signed remember-me cookie (`_blank_user_remember_me`).
3. On every request, `fetch_current_user` resolves the token, checks its validity, and assigns the `current_user` to the connection.

### Token Lifetimes

| Mechanism | Default | Config key |
|---|---|---|
| Absolute lifetime | 60 days | `config :blank, :auth, absolute_lifetime: {60, :days}` |
| Idle timeout | 4 hours | `config :blank, :auth, idle_timeout: {4, :hours}` |

The `last_activity_at` column on `blank_users_tokens` is touched on every authenticated request. If the idle timeout elapses since the last activity, the token is invalidated and the session is dropped. If the absolute lifetime elapses since token creation, the token is invalidated regardless of activity.

Duration values are `{integer, unit}` tuples where `unit` is `:minutes`, `:hours`, or `:days`.

### Logout

Logging out deletes the session token row, clears the session, removes the remember-me cookie, broadcasts a disconnect to the Admin's LiveView socket, and emits an `accounts.logout` audit entry.

## Bootstrap

Blank ships a mix task to create the first Admin from the command line:

```bash
mix blank.user.new \
  --email admin@example.com \
  --password "Str0ng!Passw0rd" \
  --name "System Admin" \
  --roles system_admin
```

Required flags: `--email`, `--password`. Optional flags: `--name`, `--roles` (comma-separated for multiple roles).

The bootstrap task always creates a **local** identity — `provider` and `external_uid` are not exposed as flags. The trust boundary is shell access: anyone with shell access already has more power than the application can grant. Unlike a perpetually-armed environment-variable grant, this is a one-shot, deliberate act with a durable audit record (`accounts.user_created`).

### Emergency IdP-Down Procedure

If you run production with `local_login: :disabled` and your IdP becomes unreachable, you can still log in to the admin panel. The documented procedure — temporarily enabling local login, creating a bootstrap Admin, and reverting — lives at `docs/ops/bootstrap.md`. The break-glass act is opening the `local_login` gate, not maintaining a permanent backdoor. The bootstrap Admin row survives the config revert; operators must clean it up themselves once IdP access is restored.
