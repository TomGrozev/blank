# Blank

Blank is a drop-in admin panel for your elixir projects. Blank fits in with your
elixir projects without needing to do much configuration to get a fully features
admin panel.

## Why make Blank?

Whatever project I made, I would always have to make an admin panel and it got
quite annoying remaking the same thing time and time again. So for one project I
decided that I would just make an easy to setup and use admin panel. At that is
where Blank comes in.

## Installation

Installation is made to be as simple as possible and can be done in 6 easy
steps.

1. Add the blank package in your project's hex dependencies.

```elixir
def deps do
  [
    {:blank, "~> 0.1.0"}
  ]
end
```

And run `mix deps.get` to fetch the blank package.

2. Add your configuration to your config file.

```elixir
config :blank,
  endpoint: MyApp.Endpoint,
  repo: MyApp.Repo,
  user_module: MyApp.Accounts.User,
  user_table: :users,
  use_local_timezone: true
```

3. Run the install command `mix blank.install` to copy required migrations and
   automatically add the required configuration options (refer to the docs for
   more info). You will need to run migrations afterwards.

4. Add the blank schema definition to your schemas that you want blank to
   control. See `Blank.Schema` for more info.

```elixir
@derive {
  Blank.Schema,
  fields: [
    title: [searchable: true],
    price: [],
  ],
  identity_field: :sid,
  order_field: :inserted_at
}
```

5. Add the blank pages to your application router.

```elixir
defmodule MyApp.Router do
  import Blank.Router

  blank_admin "/admin" do
    admin_page "/posts", MyApp.Admin.PostsLive
    admin_page "/products", MyApp.Admin.ProductsLive
  end
end
```

6. And finally add your admin pages, for example:

```elixir
defmodule MyApp.Admin.PostsLive do
  import Ecto.Query
  alias MyApp.Products.Product

  use Blank.AdminPage,
    schema: Product,
    icon: "hero-archive-box",
    index_fields: [:title, :price]
end
```

Checkout [the docs](https://hexdocs.pm/blank) for more info on configuring
Blank.
