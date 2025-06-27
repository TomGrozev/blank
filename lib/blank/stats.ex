defmodule Blank.Stats do
  @moduledoc """
  Statistics behaviour

  Used for how statistics are displayed.
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
  Simple formats a value with name

  Formats the value to be of the format `1 person` where the value is prefixed
  and the singular or plural name of the module is used.
  """
  @spec named_value(module(), number()) :: String.t()
  def named_value(module, value) when value > 1 or value < -1 do
    plural = module.config(:plural_name)

    to_string(value) <> " " <> plural
  end

  def named_value(module, _key, value) do
    name = module.config(:name)

    to_string(value) <> " " <> name
  end
end
