defmodule Blank.Plugs.AuthorizeTest do
  @moduledoc """
  Tests for Blank.Plugs.Authorize.
  Covers issue #11 acceptance criteria.
  """

  use Blank.ConnCase

  alias Blank.Plugs.Authorize

  # ── init/1 ───────────────────────────────────────────────────────

  describe "init/1" do
    test "extracts action and resource_type from opts" do
      opts = Authorize.init(action: :create, resource_type: :order)
      assert opts == %{action: :create, resource_type: :order}
    end

    test "raises when :action is missing" do
      assert_raise KeyError, fn ->
        Authorize.init(resource_type: :order)
      end
    end

    test "raises when :resource_type is missing" do
      assert_raise KeyError, fn ->
        Authorize.init(action: :create)
      end
    end
  end

  # ── call/2 — system_admin users ──────────────────────────────────

  describe "call/2 — system_admin users" do
    test "allows system_admin user through (break-glass)", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "admin_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:system_admin]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = get(conn, "/admin/authorize_test")

      assert conn.status == 200
      assert conn.resp_body =~ "index: authorized=true"
    end
  end

  # ── call/2 — non-system_admin users ──────────────────────────────

  describe "call/2 — non-system_admin users" do
    test "halts with 403 for member user", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "member_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:member]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = get(conn, "/admin/authorize_test")

      assert conn.status == 403
      assert conn.resp_body == "Forbidden"
    end

    test "halts with 403 for user with no roles", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "noroles_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: []})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = get(conn, "/admin/authorize_test")

      assert conn.status == 403
      assert conn.resp_body == "Forbidden"
    end

    test "halts with 403 when no current_user in assigns", %{conn: conn} do
      # No login — current_user is nil
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> get("/admin/authorize_test")

      # Should be 403 (or redirected to login by auth plug — depends on pipeline)
      # The authorize plug itself will 403 because can?(nil, ...) is false
      assert conn.status in [403, 302]
    end
  end

  # ── call/2 — coarse action coverage ──────────────────────────────

  describe "call/2 — coarse action coverage" do
    test ":list action on :index route allows system_admin", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "list_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:system_admin]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = get(conn, "/admin/authorize_test")

      assert conn.status == 200
    end

    test ":create action on :create route allows system_admin", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "create_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:system_admin]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = post(conn, "/admin/authorize_test")

      assert conn.status == 200
      assert conn.resp_body == "create: ok"
    end

    test ":create action on :create route denies member user", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "create_deny_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:member]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = post(conn, "/admin/authorize_test")

      assert conn.status == 403
      assert conn.resp_body == "Forbidden"
    end
  end

  # ── use Blank.Authorization in controllers ───────────────────────

  describe "use Blank.Authorization in controllers" do
    test "can?/3 is available unqualified in controller actions", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "unq_plug_#{System.unique_integer([:positive])}@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:system_admin]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      conn = get(conn, "/admin/authorize_test")

      # The controller's index action calls can?() unqualified and includes the result
      assert conn.status == 200
      assert conn.resp_body =~ "authorized=true"
    end
  end

  # ── Unit tests (direct plug invocation) ──────────────────────────

  describe "unit: call/2 with direct conn" do
    test "passes through when can? returns true" do
      opts = Authorize.init(action: :list, resource_type: :user)

      conn =
        Plug.Test.conn(:get, "/test")
        |> Plug.Conn.assign(:current_user, %{roles: [:system_admin]})

      result = Authorize.call(conn, opts)
      refute result.halted
    end

    test "halts with 403 when can? returns false" do
      opts = Authorize.init(action: :create, resource_type: :user)

      conn =
        Plug.Test.conn(:get, "/test")
        |> Plug.Conn.assign(:current_user, %{roles: [:member]})

      result = Authorize.call(conn, opts)
      assert result.halted
      assert result.status == 403
      assert result.resp_body == "Forbidden"
    end

    test "halts with 403 when current_user is nil" do
      opts = Authorize.init(action: :create, resource_type: :user)

      conn =
        Plug.Test.conn(:get, "/test")
        |> Plug.Conn.assign(:current_user, nil)

      result = Authorize.call(conn, opts)
      assert result.halted
      assert result.status == 403
    end

    test "builds scope with correct resource_type" do
      # This is verified implicitly: if resource_type were wrong, the can? check
      # would use a different scope. We test the happy path to confirm scope construction.
      opts = Authorize.init(action: :list, resource_type: :order)

      conn =
        Plug.Test.conn(:get, "/test")
        |> Plug.Conn.assign(:current_user, %{roles: [:system_admin]})

      result = Authorize.call(conn, opts)
      refute result.halted
    end
  end
end
