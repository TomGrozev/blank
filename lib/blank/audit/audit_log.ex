defmodule Blank.Audit.AuditLog do
  @moduledoc """
  Schema modile for audit logs

  This stores information about the user that performed the action, such as
  their ip address, user agent and either their admin or user account.
  """
  use Blank.Schema.Ecto
  @timestamps_opts [type: :utc_datetime]

  defmodule InvalidParameterError do
    @moduledoc false
    defexception [:message]
  end

  @type t :: %{
          action: String.t(),
          admin: Blank.Accounts.Admin.t(),
          admin_id: String.t() | integer(),
          id: String.t() | integer(),
          inserted_at: DateTime.t(),
          ip_address: String.t(),
          params: map(),
          user: struct(),
          user_agent: String.t(),
          user_id: String.t() | integer()
        }

  schema "blank_audit_logs" do
    field(:action, :string)
    field(:ip_address, Blank.Types.IP)
    field(:user_agent, :string)
    field(:params, :map, default: %{})

    belongs_to(:admin, Blank.Accounts.Admin)
    belongs_to(:user, Application.compile_env(:blank, :user_module, Blank.Accounts.Admin))

    timestamps(updated_at: false)
  end

  @doc """
  Creates a system log

  This is a log with no user and the user agent set as `SYSTEM`.
  """
  @spec system() :: t()
  def system do
    %__MODULE__{user: nil, admin: nil, user_agent: "SYSTEM"}
  end

  @allowed_params %{
    "accounts.login" => ~w(email type),
    "*.create" => ~w(item_id),
    "*.create_multiple" => ~w(item_ids),
    "*.update" => ~w(item_id),
    "*.update_multiple" => ~w(item_ids),
    "*.delete" => ~w(item_id),
    "*.delete_all" => ~w()
  }

  @doc """
  Builds a audit log

  ## Available actions

  Star actions (e.g. `*.create`) are wildcards that allow any prefix.
  The available actions are as follows:

    #{Map.keys(@allowed_params)}
  """
  @spec build!(t(), String.t(), map()) :: t()
  def build!(%__MODULE__{} = audit_context, action, params)
      when is_binary(action) and is_map(params) do
    %{
      audit_context
      | action: action,
        params:
          Map.merge(
            audit_context.params,
            params
          )
    }
    |> validate_params!()
  end

  defp validate_params!(%{action: "app." <> _} = log), do: log

  defp validate_params!(%{action: action, params: params} = log) do
    expected_keys =
      Map.get_lazy(@allowed_params, action, fn ->
        Map.fetch!(@allowed_params, star(action))
      end)

    actual_keys =
      params
      |> Map.keys()
      |> Enum.map(&to_string/1)

    case {expected_keys -- actual_keys, actual_keys -- expected_keys} do
      {[], []} ->
        log

      {_, [_ | _] = extra_keys} ->
        raise InvalidParameterError,
              "extra keys #{inspect(extra_keys)} for action #{action} in #{inspect(params)}"

      {missing_keys, _} ->
        raise InvalidParameterError,
              "missing keys #{inspect(missing_keys)} for action #{action} in #{inspect(params)}"
    end
  end

  defp star(action) do
    [_, sub_action] = String.split(action, ".", parts: 2)

    "*.#{sub_action}"
  end
end
