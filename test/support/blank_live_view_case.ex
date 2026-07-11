defmodule Blank.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that use the LiveView testing library.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Blank.LiveViewCase

      @endpoint TestAppWeb.Endpoint
    end
  end

  setup tags do
    TestApp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_user(conn, user \\ nil) do
    user = user || user_fixture()
    token = Blank.Accounts.generate_user_session_token(user)
    Plug.Test.init_test_session(conn, %{user_token: token})
  end

  def user_fixture(attrs \\ %{}) do
    defaults = %{
      email: "test_user_#{System.unique_integer([:positive])}@example.com",
      password: "Str0ng!Passw0rd"
    }

    {roles, attrs} = Map.pop(Map.merge(defaults, attrs), :roles, [:system_admin])

    {:ok, user} = Blank.Accounts.register_user(attrs)

    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{roles: roles})
      |> TestApp.Repo.update()

    user
  end
end
