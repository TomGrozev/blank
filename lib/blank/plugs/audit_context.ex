defmodule Blank.Plugs.AuditContext do
  import Plug.Conn
  alias Blank.Audit.AuditLog

  @doc """
  Loads the audit context into the connection
  """
  def fetch_audit_context(conn, _opts) do
    assign(conn, :audit_context, get_audit_context(conn))
  end

  @doc """
  Mounts the audit context into the live session
  """
  def on_mount(:load_context, _params, _session, socket) do
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

    cond do
      not is_nil(header_ip) ->
        header_ip

      true ->
        Map.get(conn, :remote_ip)
    end
  end

  defp get_ip(%Phoenix.LiveView.Socket{} = socket) do
    header_ip =
      (Phoenix.LiveView.get_connect_info(socket, :x_headers) || [])
      |> get_ip_from_x_headers()

    cond do
      not is_nil(header_ip) ->
        header_ip

      true ->
        (Phoenix.LiveView.get_connect_info(socket, :peer_data) || %{})
        |> Map.get(:address)
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
