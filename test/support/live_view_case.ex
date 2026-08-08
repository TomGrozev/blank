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
  Logs in a user by putting the session token into the conn session.

  The session key `:user_token` matches what `Blank.Plugs.Auth`
  reads during the HTTP pipeline (`fetch_current_user`) and
  what `Blank.Plugs.Auth.on_mount(:ensure_authenticated, ...)` reads
  during the LiveView WebSocket mount (`session["user_token"]`).
  """
  @spec log_in_user(Plug.Conn.t(), Blank.Accounts.User.t()) :: Plug.Conn.t()
  def log_in_user(conn, user) do
    token = Blank.Accounts.generate_user_session_token(user)
    Phoenix.ConnTest.init_test_session(conn, %{user_token: token})
  end
end
