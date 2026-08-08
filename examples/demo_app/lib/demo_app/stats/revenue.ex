defmodule DemoApp.Stats.Revenue do
  @moduledoc """
  Custom stats module that calculates total revenue from completed orders.

  Demonstrates how to implement a custom stats module using `use Blank.Stats`.
  This module implements both `query/3` and `render/1` callbacks.
  """
  use Blank.Stats

  @impl true
  def query(multi, {key, _stat}, query) do
    import Ecto.Query

    revenue_query =
      query
      |> where([o], o.status == "completed")
      |> select([o], sum(o.total_amount))

    Ecto.Multi.one(multi, key, revenue_query)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <dt class="truncate text-sm font-medium text-base-content/50">{@name}</dt>
    <dd class="mt-1 text-3xl font-semibold tracking-tight">
      <.async_result :let={value} assign={@value}>
        <:loading>
          <div class="h-6 bg-slate-700 rounded-lg"></div>
        </:loading>
        <:failed :let={_reason}>Failed to fetch</:failed>
        {format_revenue(value)}
      </.async_result>
    </dd>
    """
  end

  defp format_revenue(nil), do: "$0.00"

  defp format_revenue(%Decimal{} = value) do
    "$#{Decimal.round(value, 2) |> Decimal.to_string()}"
  end

  defp format_revenue(value) when is_number(value) do
    "$#{:erlang.float_to_binary(value * 1.0, decimals: 2)}"
  end

  defp format_revenue(_), do: "$0.00"
end
