defmodule Blank.Authorization.RoleMappers.GitHub do
  @moduledoc """
  Built-in GitHub team → role mapper.

  Reads GitHub team slugs from `auth.extra.raw_info["teams"]` (as populated by
  a ueberauth GitHub strategy) and maps them to role atoms via the
  `team_slug_to_role:` opts key.

  ## Consumer config

      config :blank, :authorization,
        role_mapper:
          {Blank.Authorization.RoleMappers.GitHub,
           team_slug_to_role: %{
             "payments-team" => :payment_manager,
             "admins" => :system_admin
           }}

  A user who is a member of the `payments-team` GitHub team will receive
  `:payment_manager` in their `User.roles` after the ueberauth callback.

  ## Semantics

    * Team slugs are matched as exact strings against the keys of the
      `team_slug_to_role` map.
    * The returned list is de-duplicated — a user in multiple teams that map
      to the same role receives that role only once.
    * If no teams match (or no teams are present), an empty list is returned.
      The caller applies role-floor semantics (`[]` → `[:member]`).
  """

  use Blank.Authorization.RoleMapper

  @impl Blank.Authorization.RoleMapper
  @spec map_claims(Ueberauth.Auth.t(), keyword()) :: [atom()]
  def map_claims(%Ueberauth.Auth{} = auth, opts) do
    team_slug_to_role = Keyword.get(opts, :team_slug_to_role)

    if is_map(team_slug_to_role) do
      do_map_claims(auth, team_slug_to_role)
    else
      []
    end
  end

  defp do_map_claims(%Ueberauth.Auth{} = auth, team_slug_to_role) do
    auth
    |> get_teams()
    |> Enum.flat_map(fn slug ->
      case Map.get(team_slug_to_role, slug) do
        nil -> []
        role -> [role]
      end
    end)
    |> Enum.uniq()
  end

  defp get_teams(%Ueberauth.Auth{extra: %Ueberauth.Auth.Extra{raw_info: raw_info}})
       when is_map(raw_info) do
    case Map.get(raw_info, "teams") do
      teams when is_list(teams) -> teams
      _ -> []
    end
  end

  defp get_teams(_), do: []
end
