defmodule Blank.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection for controller-based tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Blank.ConnCase
      import Blank.Fixtures

      @endpoint TestAppWeb.Endpoint
    end
  end

  setup tags do
    TestApp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_user(conn, user \\ nil) do
    user = user || Blank.Fixtures.user_fixture()
    token = Blank.Accounts.generate_user_session_token(user)
    Plug.Test.init_test_session(conn, %{user_token: token})
  end
end
