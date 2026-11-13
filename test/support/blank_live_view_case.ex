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

  import Phoenix.LiveViewTest, only: [put_connect_params: 2]

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

  @doc """
  Prepares a conn to mount with the given browser time zone.

  Enables `:use_local_timezone` for the calling test (restored on exit) and puts
  the zone into the connect params, so a connected LiveView resolves it in mount.
  """
  @spec with_browser_time_zone(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def with_browser_time_zone(conn, time_zone \\ "America/New_York") do
    previous = Application.get_env(:blank, :use_local_timezone, false)
    Application.put_env(:blank, :use_local_timezone, true)

    on_exit(fn ->
      Application.put_env(:blank, :use_local_timezone, previous)
    end)

    put_connect_params(conn, %{"time_zone" => time_zone})
  end
end
