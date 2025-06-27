defmodule Blank.Plugs.AuditContext do
  @moduledoc """
  Plug to apply the audit context

  This fetches the user's ip address, user agent and their user/admin struct and
  applies it to the `audit_context` assign. This is then used later for when
  logs are created so it is clear who performs an action.

  This module is automatically applied to all blank admin routes but you must
  add it to your app router to ensure audit logs are created for frontend
  actions.

  ## Adding to your application's router

  To do this you need to add the plug in two places, the conn pipeline and the
  live_session. For example, see below.

      import Blank.Plugs.AuditContext

      pipeline :browser do
        ...
        plug :fetch_audit_context
      end

      live_session :default,
        on_mount: [
          ...
          Blank.Plugs.AuditContext
        ] do

  Make sure that you add the audit context options **after** your user plug.
  Otherwise, it won't be able to fetch the user details.
  """

  import Plug.Conn
  alias Blank.Audit.AuditLog

  @doc """
  Loads the audit context into the plug connection
  """
  @spec fetch_audit_context(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def fetch_audit_context(conn, _opts) do
    assign(conn, :audit_context, get_audit_context(conn))
  end

  @doc """
  Mounts the audit context into the live session
  """
  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def on_mount(_, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :audit_context, get_audit_context(socket))}
  end

  defp get_audit_context(%Plug.Conn{} = conn) do
    user_agent =
      case List.keyfind(conn.req_headers, "user-agent", 0) do
        {_, value} -> value
        _ -> nil
      end

    %AuditLog{
      user_agent: user_agent,
      ip_address: get_ip(conn),
      user: conn.assigns[Application.get_env(:blank, :user_assigns, :current_user)],
      admin: conn.assigns[:current_admin]
    }
  end

  defp get_audit_context(%Phoenix.LiveView.Socket{} = socket) do
    %AuditLog{
      user_agent: Phoenix.LiveView.get_connect_info(socket, :user_agent),
      ip_address: get_ip(socket),
      user: socket.assigns[Application.get_env(:blank, :user_assigns, :current_user)],
      admin: socket.assigns[:current_admin]
    }
  end

  defp get_ip(%Plug.Conn{} = conn) do
    header_ip = get_ip_from_x_headers(conn.req_headers)

    if is_nil(header_ip) do
      Map.get(conn, :remote_ip)
    else
      header_ip
    end
  end

  defp get_ip(%Phoenix.LiveView.Socket{} = socket) do
    header_ip =
      (Phoenix.LiveView.get_connect_info(socket, :x_headers) || [])
      |> get_ip_from_x_headers()

    if is_nil(header_ip) do
      (Phoenix.LiveView.get_connect_info(socket, :peer_data) || %{})
      |> Map.get(:address)
    else
      header_ip
    end
  end

  defp get_ip_from_x_headers(headers) do
    with {_, ip} <- List.keyfind(headers, "x-forwarded-for", 0),
         [ip | _] = String.split(ip, ","),
         {:ok, address} <- Blank.Types.IP.cast(ip) do
      address
    else
      _ ->
        nil
    end
  end
end
