defmodule Blank.Ueberauth do
  @moduledoc """
  Ueberauth utilities for Blank.
  """

  @doc """
  Returns a human-readable display name for a ueberauth provider.

  Checks config first: `config :blank, :auth, providers: %{google: %{name: "Google"}}`
  Falls back to Phoenix.Naming.humanize/1.

  ## Examples

      iex> provider_display_name(:google)
      "Google"

      iex> provider_display_name("github")
      "GitHub"
  """
  @spec provider_display_name(atom() | String.t()) :: String.t()
  def provider_display_name(provider) when is_atom(provider) do
    provider |> Atom.to_string() |> provider_display_name()
  end

  def provider_display_name(provider) when is_binary(provider) do
    # Use to_existing_atom to avoid atom exhaustion from untrusted input
    provider_atom =
      try do
        String.to_existing_atom(provider)
      rescue
        ArgumentError -> nil
      end

    config_name =
      with atom when not is_nil(atom) <- provider_atom,
           config when is_list(config) <- Application.get_env(:blank, :auth, []),
           providers when is_map(providers) <- Keyword.get(config, :providers, %{}),
           provider_config when is_map(provider_config) <- Map.get(providers, atom) do
        Map.get(provider_config, :name)
      else
        _ -> nil
      end

    config_name || Phoenix.Naming.humanize(provider)
  end

  def provider_display_name(_), do: "Unknown"
end
