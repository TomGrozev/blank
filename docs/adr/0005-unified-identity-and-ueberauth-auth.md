# Unified identity model and ueberauth-configurable auth surface

Blank's identity surface was bifurcated: `Blank.Accounts.Admin` (email/password, Bcrypt, always-on local login) was the panel's own auth, while a separately configured host `user_table` was referenced by audit logs but had no auth flow. This forced audit logs to dual-FK (`admin_id` → `blank_admins`, `user_id` → host table), made the connection between "logged-in session" and "audited identity" implicit, and left no place for an external Identity Provider to enter the pipeline. The split is collapsed: one `blank_users` table holds every logged-in identity — both the local email/password kind and any ueberauth-strategy kind — and every audit log points at it through a single `user_id` FK.

## Decisions

**One User table, one identity source per row.** `blank_users` carries `email`/`name` (mutable display), `hashed_password` (nil for ueberauth-only), `provider` (nil for local-only), `external_uid` (the IdP-side UID — e.g. OIDC `sub`; nil for local), `roles: {:array, :atom}` (default `[]`), and a unique index apiece on `(provider, external_uid)` and on `email` filtered to `provider IS NULL`. Composite `(provider, external_uid)` is the external identity key; surrogate `User.id` is the FK target. No identity-linking across providers in this phase — each `(provider, external_uid)` produces its own row. Email and name are mutable display fields refreshed on every login and are never identity keys.

**Local login is config-gated; ueberauth is the general case.** `config :blank, auth: [local_login: :enabled | :dev_only | :disabled]`, default `:enabled`. ueberauth becomes a hard dependency of the library (`{:ueberauth, "~> 0.10"}`) so the router macro and callback controller compile unconditionally against `Ueberauth` plug and `%Ueberauth.Auth{}`. `ueberauth_oidcc` is one optional strategy dep (hosts opt in for OIDC specifically); other strategies (Google, GitHub, Auth0, custom) are host-added deps. Blank never references a specific strategy module from its own lib code — Blank is provider-agnostic. Hosts configure ueberauth per its docs (`config :ueberauth, Ueberauth, providers: [...]` and, for ueberauth_oidcc, `config :ueberauth_oidcc, :issuers, [...]`); Blank's own `config :blank, :auth, providers: %{atom: %{...}}` namespace is reserved for per-provider claim-reader/mapper config that later phases fill. The provider atom is the routing key and must match across both namespaces.

**The auth plug surface renames and the audit FK collapses.** `Blank.Plugs.Auth.fetch_current_admin/2` becomes `fetch_current_user/2`; the `on_mount` LiveView hooks become `:mount_current_user`, `:ensure_authenticated`, `:redirect_if_user_is_authenticated`; the conn plugs become `require_authenticated_user`, `redirect_if_user_is_authenticated`. The `:current_admin` assign becomes `:current_user` everywhere (router pipeline, audit context, layout header, profile page, controller, tests). `blank_audit_logs` drops `admin_id` entirely — only `user_id` references `blank_users`. `Blank.Audit.Context` populates `user:` only, dropping the `admin:` key. The vestigial `:user_module`/`:user_table`/`:user_table_pk`/`:user_table_pk_type`/`:user_assigns` config keys are removed — the unified schema is no longer configurable; one table owns the relationship. The `blank_admin` router macro name is preserved — it names the panel's function (administration), not the user type — but its internals are rewired to the renamed plugs. ueberauth request/callback routes install unconditionally inside the macro; provider availability is driven entirely by ueberauth config, not macro options.

**Bootstrap is a mix task, never a runtime grant.** `mix blank.user.new --email --password --name --roles` creates a local User row (only local — `provider`/`external_uid` are not exposed). The trust boundary is shell access: anyone with shell already has more capability than the app can grant. There is no `Bootstrap.maybe_grant/1` hook in `log_in/3`, no env-var-conditional runtime grant, no perpetually-armed break-glass credential. Production deployments that disable local login still bootstrap by SSH-ing to the box, temporarily setting `local_login: :enabled` in config, restarting the app, creating the user, then reverting — the deliberate "break glass" act is opening that gate. Each mix task run emits an `accounts.user_created` audit entry recording `email` and `roles` (provider is always local and omitted).

**Klaxon if no login path is configured.** `Blank.Application.start/1` raises if `local_login != :enabled` and no ueberauth providers are configured, with the actionable message: "Blank has no login path: local_login is disabled and no ueberauth providers are configured. Enable local_login or configure at least one ueberauth provider." `LoginLive` independently renders an admin-contact error if both are absent at render time, covering runtime config changes that slip past the boot check.

**Audit lifecycle becomes a triple.** `log_in/3` derives its audit params from the User struct itself — `type: "local"` when `provider == nil`, otherwise `type: "ueberauth"` and `provider: user.provider` (a strategy-agnostic family-level label; the specific strategy — `:oidc`, `:google`, etc. — rides on `provider`). `log_out/1` emits `accounts.logout` before clearing the session — the token-row deletion is not a durable logout trace, so the audit entry is. Ueberauth callback failures AND local login wrong-password both emit `accounts.login_failed`. New `@allowed_params` entries: `"accounts.login" => ~w(email type provider)`, `"accounts.login_failed" => ~w(email provider reason)`, `"accounts.logout" => ~w(email provider)`, `"accounts.user_created" => ~w(email roles)`. Reasons are plain strings ("wrong_password", "missing_csrf", ...), never atoms — JSON round-trip in `params :map` is unambiguous and strategy-agnostic on this shape.

`push_pubsub/1` in `Blank.Audit` becomes resilient to PubSub being down: `try ... catch :exit, _ -> :ok end` around the broadcast. The audit row (already `insert!`-persisted) is the durable artifact; broadcast is best-effort UX. Mix tasks call `log!/3` unchanged from web paths — no API divergence, no app-boot ceremony.

**User surface on login.** The ueberauth callback controller upserts the User: lookup by `(provider, external_uid)` where `external_uid = auth.uid` and `provider = Atom.to_string(auth.provider)`; if found, refresh `email`/`name` from current claims (idempotent via Ecto's no-op changeset); if not found, insert a new User with `provider`, `external_uid`, `email`, `name`, `hashed_password: nil`, `roles: [:member]`. Both first-login and mix-task creation emit `accounts.user_created`; the SessionController.local path and the ueberauth callback path both funnel through `log_in/3`, which emits `accounts.login`. The login page is a unified chooser: local form rendered when `local_login` is enabled, plus a strategy button per configured ueberauth provider (introspected from `Application.get_env(:ueberauth, Ueberauth)[:providers]`); button labels pull `:label` from `config :blank, :auth, providers: %{atom: %{label: ...}}` and fall back to title-casing the provider atom. Profile page conditional-renders on `user.provider`: local users see the password-change form; ueberauth users see a read-only identity card with name, email, provider label, and roles plus a "Managed by your identity provider" notice.

**Stubs that later phases fill.** The callback controller writes `roles: [:member]` for new ueberauth users unconditionally; per-provider claim-based and MFA-based role mappers, the role-validation gate on write, the `Blank.Authorization` module and `register_roles/1` mechanism, and the `can?/3` policy dispatch are all deferred to a subsequent phase. This phase ships only the dispatch surface against which mappers plug in. `blank_users_tokens` carries a `last_activity_at :utc_datetime` column created now — 60-day validity via `@session_validity_in_days 60` remains the default; session-lifetime enforcement (30-day absolute cap + 4-hour idle timeout) plugs into `fetch_current_user/2` in a subsequent phase. Until then, `last_activity_at` exists but is unused.

## Migrations

A clean slate. The existing integer-prefixed migration files (`1_blank_create_admins_auth_tables.exs`, `2_blank_create_audit_log.exs`, `3_blank_add_audit_actor_and_extra.exs`, and their Arango mirrors) are deleted. New `1_blank_create_users_auth_tables.exs` creates `blank_users` and `blank_users_tokens` (with `last_activity_at`). New `2_blank_create_audit_log.exs` creates `blank_audit_logs` with both the single-`user_id` FK shape AND the `actor_display_name`/`actor_email`/`extra` columns inlined, folding the prior ALTER migration's content. Test-support mirror migrations follow the same reorganization. `mix blank.admin.new` is removed; `mix blank.user.new` replaces it.

This is a hard breaking change. Blank is in active development and has no downstream consumers to protect; no compat layer and no data migration ship. The integer-prefix migration scheme is preserved — `mix blank.install` dedupes copied migration filenames on a 15-char timestamp slice, so the prefix is load-bearing, not arbitrary.

## Considered Options

**Identity model.**

- **One `blank_users` table, nullability as the discriminator** (chosen) — local fields (`hashed_password`) and ueberauth fields (`provider`, `external_uid`) coexist with nullable columns; each row's set of populated columns reveals its identity source. Simplest and only shape compatible with collapsing audit to one `user_id` FK.
- **Core table + identity-link table** — separate "user" + "user identity per provider" tables. Cleaner if per-user identity linking is needed in the future, but adds a join on every login and produces a `User` entity not directly tied to one identity source. Per-user cross-provider identity-linking is explicitly a future feature, not a launch-day requirement.
- **Two parallel `blank_admins`/`blank_users` tables** — perpetuates the bifurcation the decision discards.

**Assign name.**

- **Hardcoded rename to `:current_user`** (chosen) — one place to look, consistent with the unified identity, rewritten mechanically across the router pipeline, audit context, layout header, profile page, controller, and tests.
- **Configurable assign name via Blank config** — extra indirection with no payoff; the rename is already forced by the model change but the assign key should not also be configurable.
- **Renamed `:current_admin` keeps backward-compat alias** — perpetuates the `_admin_` vocabulary the rename discards; the panel *function* is admin, the user *identity* is user.

**Auth strategy dependency posture.**

- **ueberauth hard, ueberauth_oidcc optional** (chosen) — ueberauth is foundational to the auth surface; the router macro and callback controller compile unconditionally against `Ueberauth`. ueberauth_oidcc is one strategy among many.
- **Both hard** — drags OIDC into local-only prod consumers for no reason.
- **Both optional** — requires conditional compilation gates in the router macro and callback controller; fragile, multiplies branches for every consumer.

**Bootstrap mechanism.**

- **Mix task creating local users only** (chosen) — shell access IS the break-glass perimeter; env-var identity-match is a perpetually-armed credential, the mix task is a one-shot; no runtime grant machinery, no `log_in/3` hook, no auto-armed drift surface.
- **Per-login conditional grant based on env-var identity** — perpetually armed, drift between env-var matcher and IdP state over time; requires a `Bootstrap.maybe_grant/1` hook in `log_in/3` and a persistence choice (session-only vs DB-persisted) that adds further decisions.
- **Mix task that can also create ueberauth-shape users via CLI args (`--provider --external-uid`)** — produces a ueberauth-capable row from the shell that the host can then log in via IdP; but exposing `provider`/`external_uid` from the shell creates a confusing parallel identity authority alongside the IdP.
- **Pure ops ceremony: flip `local_login` config and restart, no code** — same as the chosen option folded into a documented procedure; mixing it with code enforcement adds no real safety since shell already grants more power.

**Audit FK shape.**

- **Single `user_id` FK on `blank_audit_logs`** (chosen) — follows from the unified identity; one actor path, one audit lookup.
- **Keep both `admin_id` and `user_id`** — preserves the bifurcation for any quasi-host-user retention; with the unified User table the distinction is pointless — operators ARE users.

**Audit broadcast resilience.**

- **`try/catch :exit` in `push_pubsub/1`** (chosen) — audit row is durable, broadcast is best-effort. Catches `:noproc` (mix task) and prod hiccups (web path). `:error` deliberately not caught — that would swallow real bugs.
- **Separate `log_without_broadcast!/3` API for mix tasks** — divergent API forces callers to choose; load-bearing runtime-login-mistake potential.
- **Mix task starts the entire `:blank` app** — heavy, fragile, slow mix-task boot for a class-of-caller the audit API already serves.

**Migration strategy.**

- **Clean slate integer-prefixed migrations** (chosen) — old table drops folded into new `1_*`/`2_*` files; the install task's filename-deduplication logic depends on the 15-char timestamp slice, so integer prefixes are load-bearing not arbitrary.
- **Versioned ALTERs on existing migrations** — preserves state for hypothetical consumers (none exist); adds ALTER churn for tables that get dropped.

**Hard break vs compat.**

- **Hard break, no compat layer** (chosen) — Blank is in active development, no downstream consumers; compat layers for a half-done design are anti-pattern.
- **Compat layer with deprecation** — doubles the surface that has to be deprecated/removed in a later release; not justified with no consumers.

**Capability-gate on role write.**

- **Not in this phase** (chosen) — role validation (`Blank.Authorization.validate_roles/1`, registration mechanism) is the entire authorization framework, which belongs in a subsequent phase; `mix blank.user.new --roles` writes atoms directly via Ecto's `{:array, :atom}` serialization in the meantime.
- **Stub `Blank.Authorization.validate_roles/1` shipped with built-in `:system_admin`/`:member` allowed-set** — would couple this phase to the authorization phase; role-validation semantics only make sense once `:policy_module` registration exists.
