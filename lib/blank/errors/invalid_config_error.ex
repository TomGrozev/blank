defmodule Blank.Errors.InvalidConfigError do
  @moduledoc false

  defexception [
    :caller,
    :module,
    :usage,
    :key,
    :message,
    :value,
    :keys_path,
    source: :nimble
  ]

  @type t :: %__MODULE__{
          caller: atom(),
          module: module(),
          usage: String.t(),
          key: atom(),
          message: String.t() | nil,
          value: term(),
          keys_path: [atom()] | nil,
          source: :nimble | :app_env
        }

  def message(%{source: :app_env} = err) do
    """
    invalid #{atom_label(err.module)} configuration

    The `#{atom_label(err.caller)}` config key is invalid.

    #{String.trim_trailing(err.usage)}

    Got: #{inspect(err.value)}
    """
  end

  def message(%{} = err) do
    """
    invalid #{atom_label(err.module)} configuration

    An invalid option was passed to `#{err.usage} #{err.module}` in the module `#{atom_label(err.caller)}`.

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

  @doc false
  @spec from_app_env(keyword()) :: t()
  def from_app_env(opts) do
    %__MODULE__{
      caller: Keyword.fetch!(opts, :caller),
      module: Keyword.fetch!(opts, :module),
      usage: Keyword.fetch!(opts, :usage),
      key: Keyword.fetch!(opts, :key),
      value: Keyword.fetch!(opts, :value),
      source: :app_env
    }
  end

  # A real module renders as a dotted name; any other atom (an application-config
  # key such as `:authorization`) renders as its inspected form.
  defp atom_label(atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> _ -> atom |> Module.split() |> Enum.join(".")
      _ -> inspect(atom)
    end
  end
end
