if Code.ensure_loaded?(ArangoXEcto.Schema) do
  defmodule Blank.Schema.Ecto do
    @moduledoc false
    defmacro __using__(_opts) do
      quote do
        use ArangoXEcto.Schema

        @binary_type :string
      end
    end
  end
else
  defmodule Blank.Schema.Ecto do
    @moduledoc false
    defmacro __using__(_opts) do
      quote do
        use Ecto.Schema

        @binary_type :binary
      end
    end
  end
end
