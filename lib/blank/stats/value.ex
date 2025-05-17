defmodule Blank.Stats.Value do
  use Blank.Stats

  @impl Blank.Stats
  def render(assigns) do
    ~H"""
    <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">{@name}</dt>
    <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-white">
      <.async_result :let={value} assign={@value}>
        <:loading><div class="h-6 bg-slate-700 rounded-lg"></div></:loading>
        <:failed :let={_reason}>Failed to fetch</:failed>
        {value}
      </.async_result>
    </dd>
    """
  end

  @impl Blank.Stats
  def query(multi, {key, _def}, query) do
    Ecto.Multi.one(multi, key, query)
  end
end
