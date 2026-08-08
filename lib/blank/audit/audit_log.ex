defmodule Blank.Audit.AuditLog do
  @moduledoc """
  Ecto schema for the `blank_audit_logs` table.

  Each record captures a mutation (create, update, or delete) along with
  metadata about who performed it:

    * `:action` — the action string (e.g. `"posts.create"`, `"app.send_email"`).
    * `:ip_address` — the User's IP address (stored as a `Blank.Types.IP`).
    * `:user_agent` — the browser user agent string (or `"SYSTEM"` for
      automated logs).
    * `:params` — a map of additional context (e.g. `%{item_id: 123}`).
    * `:user` — the `belongs_to` association for the acting User.

  ## System logs

  Use `system/0` to create an audit log with no associated user and a
  `"SYSTEM"` user agent — useful for background jobs or automated actions.

  ## Building logs

  Use `build!/3` with an audit context, an action string, and a params map.
  The params map is validated against `@allowed_params` for built-in actions.
  Wildcard actions (e.g. `"*.create"`) accept any prefix — the validation
  only checks the suffix.

  Custom app actions prefixed with `"app."` (e.g. `"app.send_email"`) skip
  parameter validation entirely.
  """
  use Blank.EctoSchema
  @timestamps_opts [type: :utc_datetime]

  defmodule InvalidParameterError do
    @moduledoc false
    defexception [:message]
  end

  @type t :: %{
          action: String.t(),
          actor_display_name: String.t() | nil,
          actor_email: String.t() | nil,
          extra: map(),
          id: String.t() | integer(),
          inserted_at: DateTime.t(),
          ip_address: String.t(),
          params: map(),
          user: Blank.Accounts.User.t(),
          user_agent: String.t(),
          user_id: String.t() | integer()
        }

  schema "blank_audit_logs" do
    field(:action, :string)
    field(:ip_address, Blank.Types.IP)
    field(:user_agent, :string)
    field(:params, :map, default: %{})
    field(:actor_display_name, :string)
    field(:actor_email, :string)
    field(:extra, :map, default: %{})

    belongs_to(:user, Blank.Accounts.User)

    timestamps(updated_at: false)
  end

  @doc """
  Creates a system log

  This is a log with no user and the user agent set as `SYSTEM`.
  """
  @spec system() :: t()
  def system do
    %__MODULE__{user: nil, user_agent: "SYSTEM", extra: %{}}
  end

  @allowed_params %{
    "accounts.login" => ~w(email type provider),
    "accounts.login_failed" => ~w(email provider reason),
    "accounts.logout" => ~w(email provider),
    "accounts.user_created" => ~w(email roles),
    "accounts.roles_updated" => ~w(user_id roles before_roles source),
    "*.create" => ~w(item_id),
    "*.create_multiple" => ~w(item_ids),
    "*.update" => ~w(item_id),
    "*.update_multiple" => ~w(item_ids),
    "*.delete" => ~w(item_id),
    "*.delete_all" => ~w()
  }

  @doc """
  Builds an audit log

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
