# Blank

A drop-in admin panel for Phoenix applications. Derive `Blank.Schema` on your Ecto schemas, declare admin pages with `use Blank.AdminPage`, and Blank provides CRUD, filtering, audit logging, and exports.

## Language

### Core Concepts

**Admin**:
A user who can authenticate into the admin panel and perform operations.
_Avoid_: User, account, administrator

**Admin Page**:
A CRUD page wired to a schema, declared via `use Blank.AdminPage`. Handles list, show, edit, and delete with filtering, sorting, and pagination.
_Avoid_: Dashboard, admin screen, CRUD controller

**Blank Schema**:
The protocol a host app's Ecto schema derives to integrate with Blank. Provides field definitions, changesets, identity field, and ordering hints.
_Avoid_: Ecto schema, model, resource

**Field**:
A rendering adapter for a data type. Implements the `Blank.Field` behaviour as a LiveComponent, with list, display, and form render modes.
_Avoid_: Column, attribute, form field, widget

### Audit

**Audit Log**:
A record of a mutation (create, update, or delete) with the acting Admin, action type, and relevant params. Stored in `blank_audit_logs`.
_Avoid_: History, event, change record

**Audit Context**:
Request metadata (IP address, acting Admin) collected per-request and used to populate Audit Logs.
_Avoid_: Request context, session info

### Authorization

**Authorization**:
The layer that decides whether a given Admin may perform an action on a resource. Exposed via `Blank.Authorization.can?/3` (the wrapper) and a consumer-supplied policy module implementing the `Blank.Authorization.Policy` behaviour.
_Avoid_: Permissions, access control, RBAC, authz

**Role**:
An atom (`:system_admin`, `:member`, or a consumer-configured atom like `:payment_manager`) attached to a user via `User.roles`. Roles are the unit of capability. Atoms in memory, persisted as strings on disk via the `Blank.Types.Role` custom Ecto type.
_Avoid_: Permission, group, claim, scope

**Blank.Scope**:
A struct passed to `can?/3` carrying `resource_type` (required atom), `resource_id` (optional), and `extra` (consumer escape map). Encodes "the thing being acted on and its bounds".
_Avoid_: Permission context, request scope, action context

**Policy Module**:
A consumer module implementing the `Blank.Authorization.Policy` behaviour's `policy/3` callback. Decides per `{user, action, scope}` triples whether the action is allowed. Composes over `Blank.Authorization.DefaultPolicy` via the `use Blank.Authorization.Policy` macro.
_Avoid_: Authz rules, permission set, capability matrix

**DefaultPolicy**:
Blank's built-in policy module, used when no `:policy_module` is configured. Closed-by-default: returns `false` for all non-`:system_admin` calls. `:system_admin` is short-circuited to `true` by the wrapper, not by DefaultPolicy.
_Avoid_: Built-in policy, fallback policy, base policy

**Role Mapper**:
A consumer-supplied module implementing the `Blank.Authorization.RoleMapper` behaviour. Called on every ueberauth callback to convert IdP claims into a list of role atoms overwriting `User.roles`. Blank ships built-in mappers for GitHub and OIDCC.
_Avoid_: Claim reader, group mapper, role extractor

**Break-Glass**:
The `:system_admin` short-circuit in `Blank.Authorization.can?/3` — always returns `true` for users holding the `:system_admin` role, regardless of policy module. Consumer policies never see `:system_admin` cases.
_Avoid_: Superuser, root, bypass, override

**Bootstrap**:
The act of granting the first `:system_admin` role so a system can be administered. In Blank, bootstrap is performed exclusively via `mix blank.user.new --roles system_admin` from the shell. No runtime env-var-based bootstrap mechanism exists (per-login env-var bootstrap grant dropped; ADR-0005's stance reaffirmed).
_Avoid_: First-time setup, init grant, seed admin

### Data Export

**Exporter**:
An adapter that produces a downloadable file (CSV, QR code) from a schema query. Implements the `Blank.Exporter` behaviour.
_Avoid_: Report generator, serializer

**Download Agent**:
A GenServer that maps short-lived download IDs to temp file paths with TTL expiry.
_Avoid_: File cache, download manager

### Rendering

**Path Prefix**:
The URL prefix where the admin panel is mounted, set by the `blank_admin` router macro. Threaded through field rendering so fields can build URLs without reaching into the router.
_Avoid_: Base path, mount point, admin URL
