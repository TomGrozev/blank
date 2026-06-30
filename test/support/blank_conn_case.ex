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

      @endpoint TestAppWeb.Endpoint
    end
  end

  setup tags do
    TestApp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_admin(conn, admin \\ nil) do
    admin = admin || admin_fixture()
    token = Blank.Accounts.generate_admin_session_token(admin)
    Plug.Test.init_test_session(conn, %{admin_token: token})
  end

  def admin_fixture(attrs \\ %{}) do
    defaults = %{
      email: "test_admin_#{System.unique_integer([:positive])}@example.com",
      password: "Str0ng!Passw0rd"
    }

    {:ok, admin} =
      defaults
      |> Map.merge(attrs)
      |> Blank.Accounts.register_admin()

    admin
  end
end
