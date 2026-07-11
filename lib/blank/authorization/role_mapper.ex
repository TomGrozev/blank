defmodule Blank.Authorization.RoleMapper do
  @moduledoc """
  Behaviour for IdP claim → role mappers.

  On every ueberauth callback, the configured role mapper is invoked with the
  `Ueberauth.Auth` struct and a keyword list of options. The mapper returns a
  plain list of role atoms — no `{:ok, _} | {:error, _}` shape.

  ## Consumer config

      config :blank, :authorization,
        role_mapper: {Blank.Authorization.RoleMappers.GitHub, [team_slug_to_role: %{"payments-team" => :payment_manager}]}

  Plain module shorthand (`role_mapper: MyMapper`) means "no opts" — the mapper
  receives an empty keyword list.

  ## Role floor semantics

    * No mapper configured → user gets `[:member]`
    * Mapper returns `[]` → user gets `[:member]` (default-floor)
    * Mapper returns non-empty → user gets exactly that list (no implicit `:member` appended)

  If the returned list fails `Blank.Authorization.validate_roles/1`, login fails
  with audit event `accounts.login_failed` (`reason: "invalid_roles_from_mapper"`).
  """

  @doc """
  Maps IdP claims from a ueberauth auth struct to a list of role atoms.

  The mapper receives the full `Ueberauth.Auth.t()` struct (provider-specific
  extraction happens inside the mapper) and a keyword list of options from
  the consumer config.

  Returns a plain list of role atoms. The caller applies role-floor semantics
  and validates the result against the allowed-set.
  """
  @callback map_claims(auth :: Ueberauth.Auth.t(), opts :: keyword()) :: [atom()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Blank.Authorization.RoleMapper
    end
  end
end
