defmodule Blank.Errors.InvalidConfigError do
  @moduledoc false

  defexception [:caller, :module, :usage, :key, :message, :value, :keys_path]

  @type t :: %__MODULE__{
          caller: module(),
          module: module(),
          usage: String.t(),
          key: atom(),
          message: String.t(),
          value: term(),
          keys_path: [atom()]
        }

  def message(%{} = err) do
    """
    invalid #{err.module} configuration

    An invalid option was passed to `#{err.usage} #{err.module}` in the module `#{module_name(err.caller)}`.

    #{err.message}
    """
  end

  @doc false
  @spec from_nimble(NimbleOptions.ValidationError.t(), keyword()) :: t()
  def from_nimble(%NimbleOptions.ValidationError{} = error, opts) do
    %__MODULE__{
      caller: Keyword.fetch!(opts, :caller),
      module: Keyword.fetch!(opts, :module),
      usage: Keyword.fetch!(opts, :usage),
      key: error.key,
      keys_path: error.keys_path,
      message: Exception.message(error),
      value: error.value
    }
  end

  defp module_name(module) do
    module
    |> Module.split()
    |> Enum.reject(&(&1 == Elixir))
    |> Enum.join(".")
  end
end
