# Routing

This guide covers Blank's routing macros — how to mount the admin panel, register admin pages, configure LiveView sessions, and run multiple panels side by side.

## Overview

Blank provides two routing macros you import into your Phoenix Router:

- **`blank_admin`** — Mounts the admin panel shell at a URL prefix. It installs a pipeline, LiveView sessions, built-in pages (dashboard, profile, settings, audit log, user management), and the surrounding scope for your admin pages.
- **`admin_page`** — Registers an individual Admin Page within a `blank_admin` block. It generates the index, show, new, edit, import, and export routes for a schema.

Under the hood these are thin wrappers around Phoenix's `scope`, `live_session`, and `live` macros. You can mix Blank routes with your existing app routes in the same router.

## Basic routing

The minimal setup mounts an admin panel at `/admin` with one admin page:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  import Blank.Router

  blank_admin "/admin" do
    admin_page "/products", MyAppWeb.Admin.ProductsLive
  end
end
```

This gives you:

- `/admin` — the Dashboard (home) page.
- `/admin/log_in` and `/admin/log_out` — authentication routes.
- `/admin/profile` — the current admin's profile page.
- `/admin/settings` — app-wide settings (audit log reset, etc.).
- `/admin/audit` — the audit log viewer.
- `/admin/admins` — the built-in user management page.
- `/admin/products/` — your product index page.
- `/admin/products/new`, `/admin/products/:id`, `/admin/products/:id/edit` — CRUD routes.
- `/admin/products/import` and `/admin/products/export` — bulk data routes.

Each product route maps to a `live_action` on your `ProductsLive` module: `:index`, `:show`, `:new`, `:edit`, `:import`, or `:export`.

## `blank_admin` options

`blank_admin` accepts a path string and an optional keyword list:

```elixir
blank_admin path, opts do
  ...
end
```

### `:live_session_name`

Sets the name of the LiveView session used for authenticated routes. Defaults to `:blank_admin_panel`.

```elixir
blank_admin "/admin", live_session_name: :my_admin_session do
  admin_page "/orders", MyAppWeb.Admin.OrdersLive
end
```

This is useful when you need multiple admin panels with distinct session names, avoiding conflicts between LiveView session configurations.

### `:on_mount`

Declares custom `Phoenix.LiveView.on_mount/1` callbacks that run before every LiveView mount in the admin panel. Your callbacks are **prepended** to Blank's default hooks (`Blank.Nav`, `ensure_authenticated`, `Blank.Audit.Context`, and `authorize`), so they run first.

```elixir
blank_admin "/admin", on_mount: [MyAppWeb.LiveAuth] do
  admin_page "/users", MyAppWeb.Admin.UsersLive
end
```

A single module can be passed instead of a list:

```elixir
blank_admin "/admin", on_mount: MyAppWeb.LiveAuth do
  ...
end
```

A common use case is loading the current user from the session — see [Integration with Phoenix auth](#integration-with-phoenix-auth) below.

## Multiple `blank_admin` blocks

You can declare more than one `blank_admin` block to run separate admin panels at different URL prefixes. Each block is fully independent — its own pipeline, LiveView session, and page set.

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  import Blank.Router

  # Main admin panel for day-to-day operations
  blank_admin "/admin" do
    admin_page "/users", MyAppWeb.Admin.UsersLive
    admin_page "/orders", MyAppWeb.Admin.OrdersLive
  end

  # Separate ops panel with different pages
  blank_admin "/ops", live_session_name: :ops_panel do
    admin_page "/deployments", MyAppWeb.Admin.DeploymentsLive
  end
end
```

### Important: the first block wins for `__blank_prefix__/0`

Internally, Blank stores a single `blank_prefix` module attribute on the router, set by the **first** `blank_admin` call. Subsequent blocks do not overwrite it. The `__blank_prefix__/0` function (used by Blank pages to build internal URLs) always returns the first panel's path. If you need pages in the second panel to build URLs relative to their own path, pass the prefix explicitly via `assigns.path_prefix`.

## Built-in routes installed by `blank_admin`

Every `blank_admin` block automatically installs these routes under the given path:

| Path | Handler | Purpose |
|------|---------|---------|
| `/` | `Blank.Pages.HomeLive` | Dashboard with audit log and link cards |
| `/log_in` | `Blank.Pages.LoginLive` | Authentication form (email/password or ueberauth) |
| `/log_in` (POST) | `Blank.Controllers.SessionController` | Session creation |
| `/log_out` (DELETE) | `Blank.Controllers.SessionController` | Session destruction |
| `/profile` | `Blank.Pages.ProfileLive` | Current admin's profile and password change |
| `/settings` | `Blank.Pages.SettingsLive` | App-wide settings (audit log reset) |
| `/audit` | `Blank.Pages.AuditLogLive` | Audit log viewer |
| `/admins/` | `Blank.Pages.UsersLive` | Built-in user management (CRUD for the User schema) |
| `/auth/:provider` | `Ueberauth` | OAuth provider request |
| `/auth/:provider/callback` | `Blank.Controllers.UeberauthCallbackController` | OAuth callback |
| `/download` | `Blank.Controllers.ExportController` | File download endpoint |
| `/qrcode` | `Blank.Controllers.ExportController` | QR code generation |

These routes are installed unconditionally and cannot be disabled. The admins page (`Blank.Pages.UsersLive`) is itself an Admin Page backed by the `Blank.Accounts.User` schema, giving you user CRUD out of the box.

## How `admin_page` paths compose

Each `admin_page` call generates six LiveView routes under the path you provide:

```elixir
admin_page "/orders", MyAppWeb.Admin.OrdersLive
```

Expands to:

| Live route | `live_action` |
|-----------|---------------|
| `/orders/` | `:index` |
| `/orders/new` | `:new` |
| `/orders/import` | `:import` |
| `/orders/export` | `:export` |
| `/orders/:id` | `:show` |
| `/orders/:id/edit` | `:edit` |

### Path derivation

The path is **explicit** — you choose it. There is no automatic derivation from the schema module name. A common convention is to use the plural table name:

```elixir
# Schema source is "products" → path "/products"
admin_page "/products", MyAppWeb.Admin.ProductsLive

# Schema source is "order_items" → path "/order_items"
admin_page "/order_items", MyAppWeb.Admin.OrderItemsLive
```

### Module alias resolution

The module you pass to `admin_page` is resolved relative to the router's current scope via `Phoenix.Router.scoped_alias/2`. This means you can use short module names when the router is already scoped:

```elixir
scope "/", MyAppWeb do
  blank_admin "/admin" do
    # Resolves to MyAppWeb.Admin.ProductsLive
    admin_page "/products", Admin.ProductsLive
  end
end
```

## Route helpers and URL building

### No named route helpers

Blank scopes use `as: false`, so standard Phoenix named route helpers (like `user_path/3`) are **not** generated. Instead, use verified routes with the `~p` sigil:

```heex
<a href={~p"/admin/products"}>Products</a>
<a href={~p"/admin/products/#{@product.id}"}>View product</a>
<a href={~p"/admin/products/#{@product.id}/edit"}>Edit product</a>
```

### `__blank_prefix__/0`

The router stores the admin panel's path prefix in `__blank_prefix__/0`:

```elixir
iex> MyAppWeb.Router.__blank_prefix__()
"/admin"
```

Built-in pages use this to build internal URLs (e.g., the login page redirects there after authentication). You can call it from your own code when you need the admin root path:

```heex
<a href={~p"#{MyAppWeb.Router.__blank_prefix__()}"}>Back to admin</a>
```

### `__blank_modules__/0`

The router also tracks all admin page registrations via `__blank_modules__/0`, which returns a list of `{path, module}` tuples. Blank's dashboard uses this to generate the navigation sidebar and home page link cards.

### The `path_prefix` assign

Every LiveView in the admin panel receives a `path_prefix` assign (set from `__blank_prefix__/0`). Field components use it to construct download URLs and other path-dependent links without reaching into the router. In your own admin page hooks, use `socket.assigns.path_prefix` when you need to build URLs.

## How `blank_admin` wires up the LiveView session

Under the hood, `blank_admin` does three things:

1. **Defines a `:blank_browser` pipeline** with session fetching, CSRF protection, root layout (`Blank.LayoutView`), and Blank's auth plugs (`fetch_current_user` and `fetch_audit_context`).

2. **Creates an unauthenticated scope** (`pipe_through [:blank_browser, :redirect_if_user_is_authenticated]`) with its own `live_session` that hosts the login page and ueberauth routes. This session runs `redirect_if_user_is_authenticated` so logged-in admins are bounced to the dashboard.

3. **Creates an authenticated scope** (`pipe_through [:blank_browser, :require_authenticated_user]`) with the main `live_session`. This session includes your `:on_mount` callbacks prepended to Blank's internal hooks:
   - `Blank.Nav` — builds the navigation sidebar from registered admin pages.
   - `{Blank.Plugs.Auth, :ensure_authenticated}` — halts unauthenticated requests.
   - `Blank.Audit.Context` — collects request metadata for audit logs.
   - `{Blank.Authorization, :authorize}` — enforces the authorization policy.

## Integration with Phoenix auth

Blank's `:on_mount` option is the integration point for your app's authentication. Write an `on_mount` callback that loads the user from the session and assigns it to the socket:

```elixir
defmodule MyAppWeb.LiveAuth do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    case MyAppWeb.Auth.get_user(session) do
      nil ->
        {:halt, redirect(socket, to: "/log_in")}

      user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end
end
```

Then wire it into `blank_admin`:

```elixir
blank_admin "/admin", on_mount: [MyAppWeb.LiveAuth] do
  admin_page "/products", MyAppWeb.Admin.ProductsLive
end
```

Your callback runs **before** Blank's own auth hooks. If your callback halts, Blank's `ensure_authenticated` won't run, giving you full control over the auth flow.

**Note:** Blank's built-in auth system (email/password via `Blank.Accounts`, ueberauth via `Ueberauth`) already manages the session and `current_user` assign. You only need a custom `on_mount` if you're using your own auth layer or need to add extra assigns (e.g., organization context, theming preferences) before Blank's hooks fire.

## Where to next

- **[Authentication](/guides/introduction/Authentication.md)** — configuring login providers, ueberauth, and the bootstrap admin.
- **[Authorization](/guides/introduction/Authorization.md)** — writing a Policy Module, defining roles, and scoping access per admin page.
- **[Role Mappers](/guides/introduction/Role Mappers.md)** — mapping IdP claims to Blank roles on login.
- **[AdminPage Options](/guides/cheatsheets/AdminPage Options.md)** — all configurable options for admin pages (fields, stats, buttons).
