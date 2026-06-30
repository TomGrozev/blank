defmodule Blank.EctoSchema do
  @moduledoc false

  use_arango =
    not Application.compile_env(:blank, :force_ecto_schema, false) and
      Code.ensure_loaded?(ArangoXEcto.Schema)

  if use_arango do
    defmacro __using__(_opts) do
      quote do
        use ArangoXEcto.Schema

        @binary_type :string
      end
    end
  else
    defmacro __using__(_opts) do
      quote do
        use Ecto.Schema

        @binary_type :binary
      end
    end
  end
end
