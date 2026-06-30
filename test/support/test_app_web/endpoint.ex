defmodule TestAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :test_app

  @session_options [
    store: :cookie,
    key: "_test_app_key",
    signing_salt: "test_app_signing_salt"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :x_headers, :user_agent]]

  plug Plug.Session, @session_options
  plug TestAppWeb.Router
end
