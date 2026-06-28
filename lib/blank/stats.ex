defmodule Blank.Stats do
  @moduledoc """
  Behaviour that powers the stats row on an admin page index.

  Implement this behaviour to define how a statistic is queried and rendered
  above the record list. The built-in `Blank.Stats.Value` module provides a
  simple numeric stat; use it as-is or as a reference for your own.

  ## Callbacks

    * `c:query/3` — receives an `Ecto.Multi`, a `{key, stat}` tuple, and the
      base index query. You must add a step to the Multi using the key as the
      step name. The value returned by the query is passed to `c:render/1`.
    * `c:render/1` — receives an assigns map containing `:name` (the display
      label) and `:value` (an `Phoenix.LiveView.AsyncResult`). Return a
      `%Phoenix.LiveView.Rendered{}`.

  ## Configuration

  Stats are configured via the `:stats` option on `use Blank.AdminPage`. Each
  stat entry can specify:

    * `:name` — display label (auto-generated from the key if nil).
    * `:display` — the stats module to use (defaults to `Blank.Stats.Value`).
    * `:formatter` — a 2-arity function `(module, value) -> String.t()` to
      format the output, or nil for raw display.

  The `query/3` callback is only called when the stat uses a query-based
  approach (returning `{:query, query}`). For value-based stats, define a
  `c:Blank.AdminPage.stat_query/2` callback that returns `{:value, fun}`.

  See `Blank.AdminPage` for the full stats configuration reference.
  """

  @callback render(assigns :: map()) :: %Phoenix.LiveView.Rendered{}
  @callback query(
              multi :: Ecto.Multi.t(),
              {key :: atom(), stat :: Keyword.t()},
              query :: Ecto.Query.t()
            ) :: Ecto.Multi.t()

  defmacro __using__(_opts) do
    quote do
      use Blank.Web, :stat
      import Ecto.Query

      @behaviour unquote(__MODULE__)
    end
  end

  @doc """
  Simply formats a value with the schema's plural name.

  Formats the value to be of the format `1 person` where the value is prefixed
  and the plural name of the module is used.
  """
  @spec named_value(module(), number()) :: String.t()
  def named_value(module, value) do
    plural = module.config(:plural_name)

    to_string(value) <> " " <> plural
  end

  @doc """
  Formats a value with the schema's singular name.

  Like `named_value/2`, but uses the schema's singular `:name` (the
  Admin Page's configured `:name` option) instead of the `:plural_name`.

  ## Parameters

    * `module` - the Admin Page module
    * `_key` - the stat key (unused; kept for arity symmetry)
    * `value` - the value to format
  """
  @spec named_value(module(), atom(), number()) :: String.t()
  def named_value(module, _key, value) do
    name = module.config(:name)

    to_string(value) <> " " <> name
  end
end
