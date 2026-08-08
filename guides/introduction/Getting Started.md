# Getting Started

Blank is a drop-in admin panel for Phoenix applications. Derive `Blank.Schema` on your Ecto schemas, declare admin pages with `use Blank.AdminPage`, and Blank gives you CRUD, filtering, audit logging, and exports with minimal configuration.

This guide walks you through installing Blank and wiring up your first admin page.

## Prerequisites

- Phoenix 1.7+
- Ecto (with a working Repo)
- Phoenix LiveView 1.1+

## Installation

Installation is made to be as simple as possible and can be done in 6 easy steps.

### 1. Add the dependency

Add Blank to your project's hex dependencies:

```elixir
def deps do
  [
    {:blank, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get`.

## Database Adapters

Blank supports two database adapters:

- **Ecto/PostgreSQL** (default) — Use `mix blank.install` or `mix blank.install --adapter ecto_sql`
- **ArangoDB** — Use `mix blank.install --adapter arango`

The adapter determines which migrations are copied to your app. Choose the adapter that matches your database.

### 2. Configure your app

Add the configuration to your config file:

```elixir
config :blank,
  endpoint: MyApp.Endpoint,
  repo: MyApp.Repo,
  user_module: MyApp.Accounts.User,
  user_table: :users,
  use_local_timezone: true
```

### 3. Run the install command

```bash
mix blank.install
```

This copies required migrations and automatically adds the required configuration options. You will need to run `mix ecto.migrate` afterwards.

### 4. Derive Blank.Schema

Add the `Blank.Schema` derivation to the schemas you want Blank to control:

```elixir
defmodule MyApp.Products.Product do
  use Ecto.Schema

  @derive {
    Blank.Schema,
    fields: [
      title: [searchable: true],
      price: []
    ],
    identity_field: :title,
    order_field: :inserted_at
  }

  schema "products" do
    field(:title, :string)
    field(:price, :decimal)
    timestamps()
  end
end
```

See `Blank.Schema` for the full list of options including `:create_changeset`, `:update_changeset`, and `:flop_opts`.

### 5. Set up routing

Add the blank routes to your application router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  import Blank.Router

  scope "/", MyAppWeb do
    pipe_through [:browser]
  end

  blank_admin "/admin" do
    admin_page "/products", MyAppWeb.Admin.ProductsLive
  end
end
```

See `Blank.Router` for advanced options like custom `on_mount` callbacks and live session names.

### 6. Create an admin page module

Finally, declare your admin page:

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  alias MyApp.Products.Product

  use Blank.AdminPage,
    schema: Product,
    icon: "hero-archive-box",
    index_fields: [:title, :price]
end
```

That's it — you now have a full CRUD admin panel for your `Product` schema at `/admin/products`.

## Declaring a Blank Schema

When you `@derive Blank.Schema`, you tell Blank how to treat each Ecto schema. The key options are:

- **`fields:`** — a keyword list of field names to their options. You can set `:searchable`, `:sortable`, `:viewable`, `:readonly`, `:label`, `:module` (to override the Field adapter), and more. See `Blank.Schema` and `Blank.Field` for the full reference.
- **`:identity_field`** — the field used as the display name for records (e.g. `:title` or `:email`). Defaults to the first primary key.
- **`:order_field`** — the field used for default ordering in list views. Defaults to `{first_pk, :asc}`.
- **`:create_changeset` / `:update_changeset`** — custom changeset functions. Defaults to the schema's `changeset/2`.

Blank follows a `*.create` / `*.update` / `*.delete` audit action convention. When a record is created through the admin panel, the audit log is tagged `"products.create"`, and so on. This convention is wired into `Blank.Audit` automatically.

## Building an Admin Page

An admin page is a LiveView module that uses `Blank.AdminPage`. It provides:

- An **index** page listing all records with filtering, sorting, and pagination.
- A **show** page for viewing individual records.
- An **edit** page for updating records.
- A **new** page for creating records.

Here's a more complete example:

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  alias MyApp.Products.Product

  use Blank.AdminPage,
    schema: Product,
    icon: "hero-archive-box",
    name: "product",
    plural_name: "products",
    index_fields: [:title, :price],
    show_fields: [:title, :price, :inserted_at],
    edit_fields: [:title, :price]
end
```

You can also implement optional callbacks:

- `c:Blank.AdminPage.stat_query/2` — to define custom statistics for the index page.
- `c:Blank.AdminPage.render_new/1` — to override the "new" page rendering.
- `c:Blank.AdminPage.admin_hook/3` — to intercept LiveView lifecycle events.

See `Blank.AdminPage` for the full option reference and callback documentation.

## Routing

Blank provides two router macros:

- **`blank_admin/3`** — mounts the admin panel at the given path prefix. All admin pages and built-in routes (login, audit, settings) live under this prefix.
- **`admin_page/2`** — registers an admin page module at a specific path within the admin panel.

```elixir
blank_admin "/admin" do
  admin_page "/posts", MyAppWeb.Admin.PostsLive
  admin_page "/products", MyAppWeb.Admin.ProductsLive
end
```

This gives you:

| Path | Action |
|------|--------|
| `/admin/posts` | Index |
| `/admin/posts/new` | New |
| `/admin/posts/:id` | Show |
| `/admin/posts/:id/edit` | Edit |

See `Blank.Router` for options like custom `:on_mount` callbacks and live session names.

## Where to next?

- `Blank.Audit` — automatic audit logging on every Admin Page mutation.
- `Blank.Exporter` — CSV and QR code exports, plus a behaviour for custom Exporter modules.
- `Blank.Field` — built-in Fields and the contract for writing your own.
- `Blank.Stats` — summary statistics on the index page.
- `Blank.Schema` — all the options you can pass when deriving a Blank Schema.
