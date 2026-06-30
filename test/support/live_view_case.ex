defmodule TestAppWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that use the LiveView testing library.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import TestAppWeb.LiveViewCase

      @endpoint TestAppWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs in an admin by putting the session token into the conn session.

  The session key `:admin_token` matches what `Blank.Plugs.Auth`
  reads during the HTTP pipeline (`fetch_current_admin`) and
  what `Blank.Plugs.Auth.on_mount(:ensure_authenticated, ...)` reads
  during the LiveView WebSocket mount (`session["admin_token"]`).
  """
  @spec log_in_admin(Plug.Conn.t(), Blank.Accounts.Admin.t()) :: Plug.Conn.t()
  def log_in_admin(conn, admin) do
    token = Blank.Accounts.generate_admin_session_token(admin)
    Phoenix.ConnTest.init_test_session(conn, %{admin_token: token})
  end
end
