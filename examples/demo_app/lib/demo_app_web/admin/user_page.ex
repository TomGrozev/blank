defmodule DemoAppWeb.Admin.UserPage do
  @moduledoc """
  Admin page for managing users.

  Demonstrates:
  - Basic admin page setup with `use Blank.AdminPage`
  - Custom stats (total count)
  - Searchable fields (name, email)
  - Sortable fields (name, status)
  """
  use Blank.AdminPage,
    schema: DemoApp.Accounts.User,
    icon: "hero-users",
    stats: [
      total: [name: "Total Users"],
      active: [name: "Active Users"]
    ]

  @impl Blank.AdminPage
  def stat_query(:active, query) do
    import Ecto.Query
    {:query, from(i in subquery(query), where: i.status == "active", select: count(i.id))}
  end
end
