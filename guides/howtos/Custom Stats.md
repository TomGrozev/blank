# How to Write a Custom Stat

This guide walks through adding summary statistics to the top of an admin page index — both configuring the built-in total count and writing your own custom stat modules.

## Overview

A Stat is a summary tile rendered above the record list on an admin page index. Each stat queries a value asynchronously and displays it with a label and optional formatting. Blank ships with a default `:total` stat that counts records in the schema, and you can add your own stats that query arbitrary data or extract values from the page assigns.

Stats are configured via the `:stats` option on `use Blank.AdminPage` and can use either of two approaches:

- **Query stats** — run an Ecto query to fetch a value. Requires implementing `stat_query/2` on your Admin Page and optionally providing a custom `Blank.Stats` module for rendering.
- **Value stats** — extract a value from the page assigns. Only requires implementing `stat_query/2`.

## Configuring stats on an admin page

Add a `:stats` keyword list to your `use Blank.AdminPage` declaration. Each key names a stat, and the value is a keyword list of options:

```elixir
use Blank.AdminPage,
  schema: MyApp.Order,
  stats: [
    total: [name: "Total Orders"],
    revenue: [name: "Revenue", display: MyApp.Stats.Revenue],
    in_stock: [name: "In Stock"]
  ]
```

Each stat entry accepts these options:

| Option | Type | Default | Description |
|---|---|---|---|
| `:name` | `String.t()` or `nil` | auto-generated | Display label. Defaults to a humanized version of the key plus the schema's plural name (e.g. `"Total orders"` for key `:total`). |
| `:display` | `atom()` | `Blank.Stats.Value` | The stat module that renders the tile. Must implement the `Blank.Stats` behaviour. |
| `:formatter` | `(module(), value()) -> String.t()` or `nil` | `&Blank.Stats.named_value/2` | A function applied to the raw value before rendering. `nil` means no formatting — the raw value passes through. |

The default `:total` stat has `formatter: nil` so its value is displayed raw. All other stats default to `&Blank.Stats.named_value/2` which appends the schema's plural name (e.g. `"5 orders"`).

If you don't include a `:total` entry in `:stats`, the total stat will not appear. To disable all stats (including the default total), set `stats: []`.

## The built-in total stat

The `:total` stat counts the total number of records for the Admin Page's schema. If you don't override `stat_query/2` for `:total`, Blank falls back to a simple `COUNT(*)` query on the index query:

```elixir
# Default fallback (you don't need to write this):
{:query, from(i in subquery(query), select: count(i))}
```

To customise the total stat, configure its `:name` and `:formatter`:

```elixir
use Blank.AdminPage,
  schema: MyApp.Order,
  stats: [
    total: [name: "All Orders", formatter: nil],
    active: [name: "Active Orders", display: Blank.Stats.Value]
  ]
```

To filter the total (e.g. count only active orders), override `stat_query/2`:

```elixir
@impl Blank.AdminPage
def stat_query(:total, query) do
  import Ecto.Query
  {:query, from(o in subquery(query), where: o.status == :active, select: count(o.id))}
end
```

**Reminder**: the `total:` entry must appear in `:stats` for the stat to show. If you remove it from the keyword list, the fallback won't run and no total will appear.

## Query-based custom stats

A query-based stat runs an Ecto query and displays the result. It requires two pieces:

1. Override `stat_query/2` to return the query.
2. Optionally write a custom `Blank.Stats` module for rendering (otherwise `Blank.Stats.Value` is used).

### Step 1: Override `stat_query/2`

The `stat_query/2` callback receives the stat key and the base index query (with preloads, grouping, ordering, and selects stripped). Return a `{:query, query}` tuple:

```elixir
@impl Blank.AdminPage
def stat_query(:revenue, query) do
  import Ecto.Query

  {:query,
    from(o in subquery(query),
      where: o.status == :completed,
      select: coalesce(sum(o.total_amount), 0)
    )}
end
```

- The first argument is the stat key matching your `:stats` entry.
- The second argument is the filtered index query. Wrap it in `subquery/1` to avoid ambiguous column references.
- Return `{:query, query}` where the query selects a single value.

If you need a different kind of query result (e.g. multiple rows), your custom stat module's `query/3` callback can use a different Ecto.Multi operation (see below).

### Step 2: Write a custom stats module (optional)

If you need custom rendering — for example, to display currency formatting or a progress bar — implement the `Blank.Stats` behaviour:

```elixir
defmodule MyApp.Stats.Revenue do
  use Blank.Stats

  alias Phoenix.LiveView.AsyncResult

  attr :name, :string, required: true
  attr :value, AsyncResult, required: true

  @impl Blank.Stats
  def render(assigns) do
    ~H"""
    <dt class="truncate text-sm font-medium text-base-content/50">{@name}</dt>
    <dd class="mt-1 text-3xl font-semibold tracking-tight text-success">
      <.async_result :let={amount} assign={@value}>
        <:loading>
          <div class="h-6 bg-slate-700 rounded-lg"></div>
        </:loading>
        <:failed :let={_reason}>Failed to fetch</:failed>
        {amount}
      </.async_result>
    </dd>
    """
  end

  @impl Blank.Stats
  def query(multi, {key, _def}, query) do
    Ecto.Multi.one(multi, key, query)
  end
end
```

Key points about `Blank.Stats`:

- `use Blank.Stats` imports `Ecto.Query` and declares the behaviour.
- **`query/3`** receives the `Ecto.Multi` being built, a `{key, stat_config}` tuple, and the query from `stat_query/2`. You must add a step to the multi and return it. Use `Ecto.Multi.one/3` for single values or `Ecto.Multi.all/3` for lists.
- **`render/1`** receives assigns with `:name` (the display label) and `:value` (a `Phoenix.LiveView.AsyncResult`). The `:value` result has already been through the formatter by the time it reaches `render/1`. Use `<.async_result>` to handle loading, failed, and ok states.
- You must declare `attr` declarations for the assigns your `render/1` function uses, just as you would in any LiveComponent.

### Step 3: Wire it up

Configure your admin page to use the custom module:

```elixir
use Blank.AdminPage,
  schema: MyApp.Order,
  stats: [
    total: [],
    revenue: [name: "Revenue", display: MyApp.Stats.Revenue, formatter: nil]
  ]
```

Set `formatter: nil` if your custom module handles formatting itself. Otherwise the default `named_value/2` formatter will run first.

## Value-based stats

A value-based stat doesn't run a separate query — it extracts a value from the page assigns. This is useful when the data is already available (e.g. derived from the loaded records list).

Override `stat_query/2` and return a `{:value, fun}` tuple:

```elixir
@impl Blank.AdminPage
def stat_query(:average_order_value, _query) do
  getter = fn
    %{items: %{loaded: items}} when is_list(items) and items != [] ->
      avg =
        items
        |> Enum.map(& &1.total_amount)
        |> Enum.sum()
        |> Kernel./(length(items))

      {:ok, avg}

    %{items: %{loaded: _}} ->
      {:ok, 0}

    _ ->
      :loading
  end

  {:value, getter}
end
```

The function receives the socket assigns map and must return:

- `{:ok, value}` — the value to display.
- `:loading` — the items stream hasn't loaded yet.
- `:error` — something went wrong.

The function is re-evaluated every time the items list changes (e.g. after filtering or pagination). No custom stat module is required — the configured `:display` module renders the value.

## Formatters

The `:formatter` option transforms the raw query result into a display string before the stat module renders it. It's a 2-arity function receiving the Admin Page module and the raw value:

```elixir
# Default formatter (appends plural name):
def format_value(module, value) do
  to_string(value) <> " " <> module.config(:plural_name)
end
```

Set `formatter: nil` to skip formatting entirely — the raw value is passed through to the display module.

### Built-in formatters

Blank provides two built-in formatters on `Blank.Stats`:

```elixir
# Appends the schema's plural name (default for non-total stats):
Blank.Stats.named_value(module, value)
# => "42 orders"

# Appends the schema's singular name:
Blank.Stats.named_value(module, :key, value)
# => "42 order"
```

The 2-arity version is the default formatter for all non-total stats. The 3-arity version is available for use when you want singular names.

### Custom formatter

Pass a function reference in the `:formatter` option:

```elixir
stats: [
  revenue: [
    name: "Revenue",
    display: Blank.Stats.Value,
    formatter: &format_currency/2
  ]
]
```

```elixir
def format_currency(_module, value) when is_number(value) do
  "$#{:erlang.float_to_binary(value / 100, decimals: 2)}"
end
```

The formatter runs before the display module's `render/1`, so the value inside the `AsyncResult` will already be a string. If you want to keep the raw numeric value for rendering (e.g. to apply CSS classes based on the number), set `formatter: nil` and handle formatting in your custom display module's `render/1`.

## Complete example: revenue and average stats

Here's a full Admin Page with a total count, a query-based revenue stat, and a value-based average:

```elixir
defmodule MyAppWeb.Admin.OrderPage do
  use Blank.AdminPage,
    schema: MyApp.Order,
    repo: MyApp.Repo,
    stats: [
      total: [name: "Total Orders"],
      revenue: [name: "Revenue", display: MyApp.Stats.Revenue, formatter: nil],
      average: [name: "Avg. Order Value", formatter: &format_dollars/2]
    ]

  @impl Blank.AdminPage
  def stat_query(:total, query) do
    import Ecto.Query
    {:query, from(o in subquery(query), where: o.status != :void, select: count(o.id))}
  end

  def stat_query(:revenue, query) do
    import Ecto.Query
    {:query,
      from(o in subquery(query),
        where: o.status == :completed,
        select: coalesce(sum(o.total_amount), 0)
      )}
  end

  def stat_query(:average, _query) do
    getter = fn
      %{items: %{loaded: items}} when is_list(items) and items != [] ->
        avg =
          items
          |> Enum.map(& &1.total_amount)
          |> Enum.sum()
          |> Kernel./(length(items))

        {:ok, avg}

      _ ->
        :loading
    end

    {:value, getter}
  end

  defp format_dollars(_module, value) when is_number(value) do
    "$#{:erlang.float_to_binary(value / 100, decimals: 2)}"
  end
end
```

The revenue stat uses a custom display module (`MyApp.Stats.Revenue`) that renders with a green color and handles async loading. The average stat uses the built-in `Blank.Stats.Value` display with a custom dollar formatter. The total stat overrides the query to exclude void orders.

## Tips

- Use `subquery(query)` in your `stat_query/2` queries to avoid ambiguous column references when joining or filtering the base index query.
- Set `formatter: nil` on the total stat if you want the raw count — the default total already has `formatter: nil`.
- For value-based stats, the getter function runs on every `:handle_async` for the items stream, so keep it fast and side-effect-free.
- If your custom display module needs the raw numeric value (e.g. to conditionally render a red/green color), set `formatter: nil` in the stat config and do the formatting inside `render/1`.
- The `query/3` callback on your stat module can use any `Ecto.Multi` operation — not just `one/3`. Use `all/3` if your query returns multiple rows, but you'll need to handle the list result in `render/1`.

## Where to next

- [AdminPage Options cheatsheet](../cheatsheets/AdminPage%20Options.md) — full reference for all `use Blank.AdminPage` options.
- [Custom Field guide](Custom%20Field.md) — create your own field rendering components.
- [Custom Exporter guide](Custom%20Exporter.md) — add downloadable export formats to your admin pages.
