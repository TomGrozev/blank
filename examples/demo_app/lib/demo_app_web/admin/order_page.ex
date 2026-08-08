defmodule DemoAppWeb.Admin.OrderPage do
  @moduledoc """
  Admin page for managing orders.

  Demonstrates:
  - Admin page with custom stats module
  - BelongsTo relationship (user)
  - Currency field for total_amount
  - Custom revenue stat
  """
  use Blank.AdminPage,
    schema: DemoApp.Orders.Order,
    icon: "hero-shopping-bag",
    stats: [
      total: [name: "Total Orders"],
      revenue: [name: "Revenue", display: DemoApp.Stats.Revenue]
    ]
end
