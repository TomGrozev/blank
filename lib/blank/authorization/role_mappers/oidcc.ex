defmodule Blank.Authorization.RoleMappers.OIDCC do
  @moduledoc """
  Built-in OIDCC group → role mapper.

  Reads OIDC group claims from `auth.extra.raw_info["groups"]` (as populated by
  the `oidcc` library, which stores raw IdP claims in this slot) and maps them
  to role atoms via the `groups_to_roles:` opts key.

  ## Consumer config

      config :blank, :authorization,
        role_mapper:
          {Blank.Authorization.RoleMappers.OIDCC,
           groups_to_roles: %{
             "admin" => :system_admin,
             "payments" => :payment_manager
           }}

  A user whose IdP carries `groups: ["admin"]` will receive `:system_admin` in
  their `User.roles` after the ueberauth callback.

  ## Semantics

    * Group names are matched as exact strings against the keys of the
      `groups_to_roles` map.
    * The returned list is de-duplicated — a user in multiple groups that map
      to the same role receives that role only once.
    * If no groups match (or no groups are present), an empty list is returned.
      The caller applies role-floor semantics (`[]` → `[:member]`).
  """

  use Blank.Authorization.RoleMapper

  @impl Blank.Authorization.RoleMapper
  @spec map_claims(Ueberauth.Auth.t(), keyword()) :: [atom()]
  def map_claims(%Ueberauth.Auth{} = auth, opts) do
    groups_to_roles = Keyword.get(opts, :groups_to_roles)

    if is_map(groups_to_roles) do
      do_map_claims(auth, groups_to_roles)
    else
      []
    end
  end

  defp do_map_claims(%Ueberauth.Auth{} = auth, groups_to_roles) do
    auth
    |> get_groups()
    |> Enum.flat_map(fn group ->
      case Map.get(groups_to_roles, group) do
        nil -> []
        role -> [role]
      end
    end)
    |> Enum.uniq()
  end

  defp get_groups(%Ueberauth.Auth{extra: %Ueberauth.Auth.Extra{raw_info: raw_info}})
       when is_map(raw_info) do
    case Map.get(raw_info, "groups") do
      groups when is_list(groups) -> groups
      _ -> []
    end
  end

  defp get_groups(_), do: []
end
