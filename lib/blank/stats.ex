defmodule Blank.Stats do
  @moduledoc """
  Stats behaviour
  """

  alias Blank.Stats

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
  Formats a value with name
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
