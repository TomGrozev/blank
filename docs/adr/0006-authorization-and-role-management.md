# Authorization and Role Management

**Status:** Accepted (supersedes the "Bootstrap mechanism" subsection of ADR-0005 — see below)

ADR-0005 unified identity and ueberauth auth, but explicitly stubbed `Blank.Authorization` to "a subsequent phase." That phase is now this ADR. The per-login IdP claim-reader that overwrites `User.roles` was folded into this work's scope during grilling. The per-login env-var identity-matching bootstrap grant of `:system_admin` with self-healing was dropped — ADR-0005's mix-task-only bootstrap stance stands.

## Decisions

**Decision 1 — Role typology: atoms in memory, strings on disk.** `User.roles` stays an array-column but its element type changes to a custom Ecto type `Blank.Types.Role`. The schema field is declared `{:array, Blank.Types.Role}`. The underlying DB column stays `{:array, :string}` — no migration. `Blank.Types.Role` implements `Ecto.Type`: `type/0` returns `:string`; `cast/1` accepts atoms or strings and converts strings via `String.to_existing_atom/1`, reading the app-configured allowed-set at cast time and rejecting atoms not in that set; `load/1` reads `string → existing_atom`; `dump/1` writes `atom → string`. This avoids atom-table-exhaustion attack surface (IdP could send attacker-chosen strings), keeps JSON-round-trip safe at the audit-params layer, and requires no migration churn for consumers. Atoms-in-memory matches all consumer expectations (ADR-0003, ADR-0004, ADR-0008, the seam contracts use role atoms like `:system_admin`, `:member`).

**Decision 2 — Role registration: config-driven, validated on every write.** Role atoms live in consumer config:

```elixir
config :blank, :authorization,
  policy_module: MyApp.Policy,
  roles: [:org_manager, :payment_manager, :event_manager]
```

The allowed-set is `MapSet.new([:system_admin, :member | configured_roles])` — built at app boot from config. Built-ins `:system_admin` and `:member` are non-configurable constants — they always exist and cannot be removed by consumers. `Blank.Authorization.validate_roles/1` returns `:ok | {:error, [atoms]}` and is called on every role-write path (mix task, claim-reader, any future direct update path). The custom type's `cast/1` already enforces the allowed-set, so `validate_roles/1` is a list-level sanity check redundant by design — useful as a fail-safe when a caller bypasses changeset cast. No `register_roles/1` macro/API exists. No ETS, no Agent-backed registry, no runtime registration. Config is the single source of truth for the role vocabulary; compile-time-frozen atoms eliminate concurrent-mutation concerns. A `register_roles/1` macro would split the role vocabulary across two places (config + module body) for no benefit.

**Decision 3 — Action shape: bare atoms.** `can?(user, action, scope)` takes `action` as a bare atom (`:create`, `:read`, `:update`, `:delete`, `:list`, `:show`, …). The coarse permission matrix is dispatched via naked atoms. The resource being acted on lives in the `scope`, not in the action — so `:create` means "create something within this scope" and the scope says what kind of thing. Alternatives considered: `{resource, action}` tuples (doubles the matrix and forces every policy to enumerate every resource × action pair — opposite of "coarse"); separate `action` and `resource` args (cleanest conceptually but most verbose at call sites). Bare atoms chosen because the coarse matrix is bounded at the framework level and resource discrimination is naturally a scope concern.

**Decision 4 — Scope shape: `Blank.Scope` struct.**

```elixir
defmodule Blank.Scope do
  @enforce_keys [:resource_type]
  defstruct [:resource_type, :resource_id, extra: %{}]
end
```

`resource_type` (atom, required) — e.g. `:user`, `:order`, `:event`, `:audit_log`. `resource_id` (term | nil, optional) — for resource-specific checks like `:show` of a particular record. `extra` (map, default `%{}`) — the consumer escape hatch. A host app uses this for its scope dims (`bound_org_ids`, `bound_event_ids`, `bound_customer_ids`, etc.) by placing them inside `extra`. A host app's scope-loading plug emits `%Blank.Scope{resource_type: ..., extra: %{bound_org_ids: ...}}`. Blank needs `resource_type` to ship DefaultPolicy and built-in coarse checks; it cannot be opaque. Everything beyond `resource_type`/`resource_id` is consumer domain knowledge Blank should not touch.

**Decision 5 — `can?` arity and seam signature.** The seam is `Blank.Authorization.can?(user, action, scope)` — three args, user first. `user` is `Blank.Accounts.User.t()`. `action` is a bare atom. `scope` is `Blank.Scope.t()`. Three-arg form (rather than collapsing `user` into `scope`) so the wrapper's `:system_admin` short-circuit reads `user.roles` without scope introspection, and so the seam matches the intuitive phrasing "can user X do action Y to scope Z."

**Decision 6 — `DefaultPolicy` and the `:system_admin` short-circuit.** `Blank.Authorization.can?/3` is the wrapper:

```elixir
def can?(%User{roles: roles} = user, action, scope) do
  cond do
    :system_admin in roles -> true
    true                   -> apply(policy_module(), :policy, [user, action, scope])
  end
end
```

`:system_admin` is break-glass and short-circuited to `true` in the wrapper, so consumers can never forget it. `policy_module()` returns the configured `:policy_module` if set, or `Blank.Authorization.DefaultPolicy` if unset. `Blank.Authorization.DefaultPolicy` ships a closed-by-default baseline: `def policy(_, _, _), do: false`. Only `:system_admin` blanket-permits (via the wrapper short-circuit). `:member` and all other roles derive zero permissions from DefaultPolicy. The admin panel is for admins — a non-`:system_admin` user sees nothing by default; consumers extend by configuring their own `policy_module` and overriding exactly the cases they want. This is an intentional security posture change from the previous implicit "any authenticated user can do everything" behaviour.

**Decision 7 — Compositional `use Blank.Authorization.Policy` macro.** Consumer policy modules use a `use` macro that injects `DefaultPolicy.policy/3` as an overridable super:

```elixir
defmodule Blank.Authorization.Policy do
  @callback policy(
              user :: Blank.Accounts.User.t(),
              action :: atom(),
              scope :: Blank.Scope.t()
            ) :: boolean()
end

defmodule Blank.Authorization.Policy.Helpers do
  defmacro __using__(_opts) do
    quote do
      @behaviour Blank.Authorization.Policy
      def policy(user, action, scope),
        do: Blank.Authorization.DefaultPolicy.policy(user, action, scope)
      defoverridable policy: 3
    end
  end
end
```

The `@behaviour` callback is named `policy/3` — not `can?/3` — because the wrapper is named `can?/3` and the two must never collide. Consumers override `policy/3` in their module; callers always invoke `Blank.Authorization.can?/3`. The `use` macro is optional — a consumer who just declares `@behaviour Blank.Authorization.Policy` manually also works. The macro earns its keep by handling overridable-super plumbing so consumers do not have to write `def policy(...), do: DefaultPolicy.policy(...)` as a blanket tail.

**Decision 8 — Bootstrap: mix task only (ADR-0005 wins).** The `mix blank.user.new --roles system_admin` task is the only bootstrap mechanism. The per-login env-var identity-matching `:system_admin` grant, the `accounts.bootstrap_grant` audit action, the `emergency_bootstrap:` config key, and the self-healing zero-count query are all dropped. This supersedes the per-login env-var grant, not ADR-0005 — ADR-0005's "Bootstrap mechanism" subsection remains authoritative. The reasoning ADR-0005 gave (per-login env-var grant is "perpetually armed, drift between env-var matcher and IdP state") stands. Shell access remains the trust boundary. `accounts.user_created` is reused (not a new event) for the mix task path — it already has `roles` checked into its `@allowed_params` allowlist. The IdP claim-reader persists roles on every login, so bootstrap via mix task is needed only for the very first `:system_admin` before any IdP-driven grants exist.

**Decision 9 — IdP claim-reader on every login.** On every ueberauth callback (first and subsequent login), `User.roles` is overwritten by mapping IdP claims → role atoms via a configured role mapper.

Mapper behaviour: `Blank.Authorization.RoleMapper` with `@callback map_claims(auth :: Ueberauth.Auth.t(), opts :: keyword()) :: [atom()]`. The mapper returns a plain list of atoms (no `{:ok, _} | {:error, _}` shape). If the returned list fails `validate_roles/1`, login fails with audit event `accounts.login_failed` (`reason: "invalid_roles_from_mapper"`).

Consumer config:

```elixir
config :blank, :authorization,
  role_mapper: {Blank.Authorization.RoleMappers.GitHub, [team_slug_to_role: %{"payments-team" => :payment_manager}]}
```

Plain module shorthand (`role_mapper: MyMapper`) means "no opts" — the mapper ignores the opts arg. Uniform dispatch: the callback controller always passes `Ueberauth.Auth.t()` to the mapper, regardless of provider strategy. The OIDCC mapper extracts claims from `auth.extra.raw_info` itself, rather than the controller branching on provider.

Role floor semantics: when no mapper is configured → user gets `[:member]`. When mapper returns `[]` → user gets `[:member]`. When mapper returns non-empty → user gets exactly that list; no implicit `:member` is appended. The mapper author controls "exactly these roles" by returning a non-empty list. The no-mapper fallback of `[:member]` matches today's behaviour with atom semantics instead of today's `["member"]` string.

**Decision 10 — Built-in role mappers.** Blank ships `Blank.Authorization.RoleMappers.GitHub` (reads `auth.extra.teams`, maps team slugs → role atoms via a `team_slug_to_role:` map in opts) and `Blank.Authorization.RoleMappers.OIDCC` (reads claims from `auth.extra.raw_info`, maps IdP `groups` claim → role atoms via a `groups_to_roles:` map in opts). Both implement the `RoleMapper` behaviour uniformly with the `map_claims(Ueberauth.Auth.t(), opts)` signature. Additional built-ins (Google, GitLab, etc.) may be added later following the same pattern. Custom consumer mappers can ignore the `opts` arg entirely; only built-ins read their per-provider mapping from it.

**Decision 11 — Unconfigured `:policy_module` falls back to DefaultPolicy.** When `config :blank, :authorization, policy_module: ...` is unset, `Blank.Authorization.can?/3`'s `policy_module()` helper returns `Blank.Authorization.DefaultPolicy`. No raise, no error — Blank works out of the box with its closed-by-default baseline (`:system_admin` short-circuited, everyone else denied). Blank's own admin panel works for the bootstrap user (who has `:system_admin`) without any policy configuration. Consumers add policy later to unlock non-admin actions for specific roles.

**Decision 12 — Role write path and audit emission.** `Blank.Accounts.update_roles/3` is the writer-of-roles used by the IdP claim-reader path and any future direct update path. Signature (approximate): `update_roles(user, roles, source: ..., audit_context: ...)`. The function wraps the update + audit emission in an `Ecto.Multi`, calling `Blank.Audit.multi/4` for the audit insert. The caller passes `source:` (string — `"idp_claim_mapper"`, `"mix_task_modify"`, `"admin_ui"` — consumer-defined) and `audit_context:` (request metadata). The writer emits `accounts.roles_updated` with allow-list params `~w(user_id roles before_roles source)` — `before_roles` is the prior roles (loaded before update), `source` identifies the trigger, both are logged. The mix task path does not use `update_roles/3` — it uses `accounts.user_created` (already in the allow-list) because row creation and role-setting happen together.

**Decision 13 — LiveView authorizing hook.** A coarse `on_mount` authorizing hook ships as the third element in the standard router `on_mount` chain: `[{Blank.Plugs.Auth, :ensure_authenticated}, Blank.Audit.Context, Blank.Authorization]`. The router mounts authorize as `{Blank.Authorization, :authorize}` — no resource_type in the tuple.

Resource derivation: every LiveView that wants authorization declares `use Blank.Authorization, :user` (positional atom — the resource_type). `Blank.AdminPage`'s `__using__` automatically injects `use Blank.Authorization, unquote(opts[:key])` so AdminPage LiveViews get the resource_type for free from their existing `schema:`/`key:` config. No per-LiveView annotation needed for AdminPage; non-AdminPage LiveViews declare the use themselves.

`use Blank.Authorization, :user` also imports `Blank.Authorization.can?/1` / `can?/2` / `can?/3` so LiveView handlers can use the unqualified `can?(user, :create, scope)` form, which always routes through Blank's wrapper (and thus always benefits from the `:system_admin` short-circuit). Consumers never call their policy's `policy/3` directly.

Coarse action at mount: the hook calls `can?(conn_or_socket_user, :list, %Blank.Scope{resource_type: <derived>})` for index routes and `:read` for show routes. No new `:access` action is added. Deny on mount → redirect or raise early, before the LiveView mounts. Fine-grained checks (`:create`, `:update`, `:delete`, `:read` on specific resources) remain explicit `can?(user, :create, scope)` calls inside LiveView handlers — belt-and-suspenders: coarse gate at the boundary, fine gate at the action.

**Decision 14 — Non-LiveView authorization: `Blank.Plugs.Authorize` plug.** For Phoenix controllers, Absinthe via Plug pipeline, and other non-LiveView routes, Blank ships `Blank.Plugs.Authorize`. Usage: `plug Blank.Plugs.Authorize, :create when action in [:create, :index]` — runs `can?(current_user, action, %Blank.Scope{resource_type: <derived>})` at plug time and halts with 403 on deny. The plug covers coarse gate checks (`:index`, `:create`, `:list`). Fine-grained resource-specific checks (`:show` of a particular resource) happen inside controller actions via explicit `can?` calls, mirroring the LiveView split (coarse boundary, fine action). `resource_type` derivation in controllers is via the plug's own arg: `plug Blank.Plugs.Authorize, :create, resource_type: :order` or `plug Blank.Plugs.Authorize, action: :create, resource_type: :order`. The `use Blank.Authorization, :user` import works in controllers too, giving controller authors `can?/3` for explicit in-action checks.

## Consequences

### Positive

- Blank ships a fully-featured authorization layer out of the box: roles, capability gate, claim-reader wiring, audit emission.
- Security-default posture: locked-down by DefaultPolicy, `:system_admin` blanket, consumers extend selectively.
- No migrations: the custom Ecto type keeps the DB column as `{:array, :string}` so consumers on existing installs are unaffected.
- IdP-driven role flow lands in the same work unit, so admins who do not have shell access still get role propagation from IdP.
- Single derivation mechanism (`use Blank.Authorization, :resource`) — AdminPage LiveViews get it for free from existing config; non-AdminPage LiveViews declare it; controllers via the plug.
- Wrapper-vs-policy split (`can?` ≠ `policy`) closes the footgun of bypassing `:system_admin` short-circuit.
- Audit log carries full diff + source for role changes (`before_roles`, `source`), answering the most-asked audit questions for an IdP-driven system.

### Negative

- DefaultPolicy's closed-by-default posture is a behaviour change: non-`:system_admin` users see nothing in the admin panel until a consumer policy is configured. This is intentional (admin panel is for admins) but is a breaking change for any consumer relying on "any authenticated user can do anything" today.
- The `policy/3` ≠ `can?/3` distinction is unusual and may catch developers off-guard on first read (mitigated by `use Blank.Authorization` exposing only `can?`).
- The per-login env-var bootstrap grant was dropped: consumers in headless/container deployments where shell access is not a trust perimeter will not get a runtime bootstrap backdoor. They must either have shell access in their deployment shape or bootstrap the first `:system_admin` via deployment-time mix task before the runtime serves traffic.
- `Blank.Scope` introduces a new struct that consumers must construct — they are not just passing a map. Mitigated by being a thin struct with one required field + one optional + an escape map.
- The custom Ecto type makes cast-time rejections dependent on module-load order — registered role atoms must exist before any DB row with them loads. This is solved by registering at app boot (all atoms exist before any HTTP request), but is a property consumers should understand.

## Supersedes

This ADR supersedes the "Bootstrap mechanism" subsection of ADR-0005 only in that it restates ADR-0005's choice (mix task only, no runtime env-var grant) as authoritative and explicitly records that the per-login env-var bootstrap grant is dropped. It does not contradict ADR-0005; ADR-0005's reasoning is reaffirmed here.
