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
