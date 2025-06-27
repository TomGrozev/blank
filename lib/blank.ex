defmodule Blank do
  @moduledoc """
  ## Installation

  Installation is made to be as simple as possible and can be done in 3 easy
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

  2. Run the install command `mix blank.install` to copy required migrations and
    automatically add the required configuration options (refer to the docs for
    more info). You will need to run migrations afterwards.

  3. Add the blank pages to your application router.

  ```elixir
  defmodule MyApp.Router do
    import Blank.Router

    blank_admin "/admin" do
      admin_page "/posts", MyApp.Admin.PostsLive
      admin_page "/products", MyApp.Admin.ProductsLive
    end
  end
  ```

  Add your configuration to your config file.

  ```elixir
  config :blank,
    endpoint: MyApp.Endpoint,
    repo: MyApp.Repo,
    user_module: MyApp.Accounts.User,
    user_table: :users,
    use_local_timezone: true
  ```

  And finally add your admin pages, for example:

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
  """
end
