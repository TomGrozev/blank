defmodule Blank.Plugs.AuthTest do
  use Blank.ConnCase

  alias Blank.Plugs.Auth
  alias Blank.Accounts

  # ── local_login_enabled?/0 ──

  describe "local_login_enabled?/0" do
    test "returns true when config is :enabled" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, local_login: :enabled)
        assert Auth.local_login_enabled?() == true
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns false when config is :disabled" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, local_login: :disabled)
        assert Auth.local_login_enabled?() == false
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns true in :test env when config is :dev_only" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, local_login: :dev_only)
        assert Auth.local_login_enabled?() == true
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "defaults to true when no config set" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.delete_env(:blank, :auth)
        assert Auth.local_login_enabled?() == true
      after
        Application.put_env(:blank, :auth, original)
      end
    end
  end

  # ── idle_timeout/0 ──

  describe "idle_timeout/0" do
    test "returns default 14400 (4 hours) when not configured" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.delete_env(:blank, :auth)
        assert Auth.idle_timeout() == 4 * 3600
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns configured value converted to seconds" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, idle_timeout: {30, :minutes})
        assert Auth.idle_timeout() == 30 * 60
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :minutes unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, idle_timeout: {2, :minutes})
        assert Auth.idle_timeout() == 120
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :hours unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, idle_timeout: {1, :hours})
        assert Auth.idle_timeout() == 3600
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :days unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, idle_timeout: {2, :days})
        assert Auth.idle_timeout() == 2 * 86_400
      after
        Application.put_env(:blank, :auth, original)
      end
    end
  end

  # ── absolute_lifetime/0 ──

  describe "absolute_lifetime/0" do
    test "returns default 5184000 (60 days) when not configured" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.delete_env(:blank, :auth)
        assert Auth.absolute_lifetime() == 60 * 86_400
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns configured value converted to seconds" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, absolute_lifetime: {7, :days})
        assert Auth.absolute_lifetime() == 7 * 86_400
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :minutes unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, absolute_lifetime: {10, :minutes})
        assert Auth.absolute_lifetime() == 600
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :hours unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, absolute_lifetime: {12, :hours})
        assert Auth.absolute_lifetime() == 12 * 3600
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "supports :days unit" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, absolute_lifetime: {30, :days})
        assert Auth.absolute_lifetime() == 30 * 86_400
      after
        Application.put_env(:blank, :auth, original)
      end
    end
  end

  # ── check_token_validity/1 ──

  describe "check_token_validity/1" do
    test "returns :ok for a valid token (not expired, not idle)" do
      token = %{
        inserted_at: DateTime.utc_now(),
        last_activity_at: DateTime.utc_now()
      }

      assert Auth.check_token_validity(token) == :ok
    end

    test "returns {:error, :expired} when absolute lifetime exceeded" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, absolute_lifetime: {1, :minutes})

        two_minutes_ago = DateTime.add(DateTime.utc_now(), -120, :second)

        token = %{
          inserted_at: two_minutes_ago,
          last_activity_at: DateTime.utc_now()
        }

        assert Auth.check_token_validity(token) == {:error, :expired}
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns {:error, :idle_expired} when idle timeout exceeded" do
      original = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth,
          idle_timeout: {1, :minutes},
          absolute_lifetime: {60, :days}
        )

        token = %{
          inserted_at: DateTime.utc_now(),
          last_activity_at: DateTime.add(DateTime.utc_now(), -120, :second)
        }

        assert Auth.check_token_validity(token) == {:error, :idle_expired}
      after
        Application.put_env(:blank, :auth, original)
      end
    end

    test "returns :ok when last_activity_at is nil (no idle check)" do
      token = %{
        inserted_at: DateTime.utc_now(),
        last_activity_at: nil
      }

      assert Auth.check_token_validity(token) == :ok
    end
  end

  # ── Helper to build a mock LiveView socket ──

  defp build_socket(assigns \\ %{}) do
    default_assigns = %{__changed__: %{}, flash: %{}}

    %Phoenix.LiveView.Socket{
      assigns: Map.merge(default_assigns, assigns),
      router: TestAppWeb.Router,
      private: %{phoenix_router: TestAppWeb.Router, live_temp: %{}}
    }
  end

  # ── on_mount/4 — :mount_current_user ──

  describe "on_mount/4 — :mount_current_user" do
    test "returns {:cont, socket} with current_user assigned when session has valid token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      socket = build_socket()
      session = %{"user_token" => token}

      assert {:cont, socket} = Auth.on_mount(:mount_current_user, %{}, session, socket)
      assert socket.assigns.current_user.id == user.id
    end

    test "returns {:cont, socket} with nil current_user when no user_token in session" do
      socket = build_socket()
      session = %{}

      assert {:cont, socket} = Auth.on_mount(:mount_current_user, %{}, session, socket)
      assert socket.assigns.current_user == nil
    end
  end

  # ── on_mount/4 — :ensure_authenticated ──

  describe "on_mount/4 — :ensure_authenticated" do
    test "returns {:cont, socket} when user is present" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      socket = build_socket()
      session = %{"user_token" => token}

      assert {:cont, socket} = Auth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert socket.assigns.current_user.id == user.id
    end

    test "returns {:halt, socket} when user is nil" do
      socket = build_socket()
      session = %{}

      assert {:halt, socket} = Auth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert socket.assigns.current_user == nil
    end
  end

  # ── on_mount/4 — :redirect_if_user_is_authenticated ──

  describe "on_mount/4 — :redirect_if_user_is_authenticated" do
    test "returns {:halt, socket} with redirect when user is present" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      socket = build_socket()
      session = %{"user_token" => token}

      assert {:halt, socket} =
               Auth.on_mount(:redirect_if_user_is_authenticated, %{}, session, socket)

      assert socket.assigns.current_user.id == user.id
    end

    test "returns {:cont, socket} when user is nil" do
      socket = build_socket()
      session = %{}

      assert {:cont, socket} =
               Auth.on_mount(:redirect_if_user_is_authenticated, %{}, session, socket)

      assert socket.assigns.current_user == nil
    end
  end

  # ── redirect_if_user_is_authenticated/2 ──

  describe "redirect_if_user_is_authenticated/2" do
    test "returns conn unchanged when no current_user" do
      conn =
        Plug.Test.conn(:get, "/admin/settings")
        |> Plug.Test.init_test_session(%{})
        |> assign(:current_user, nil)
        |> put_private(:phoenix_router, TestAppWeb.Router)

      result = Auth.redirect_if_user_is_authenticated(conn, [])
      assert result == conn
    end

    test "redirects and halts when current_user is assigned" do
      user = user_fixture()

      conn =
        Plug.Test.conn(:get, "/admin/settings")
        |> Plug.Test.init_test_session(%{})
        |> assign(:current_user, user)
        |> put_private(:phoenix_router, TestAppWeb.Router)

      result = Auth.redirect_if_user_is_authenticated(conn, [])
      assert result.halted == true
      assert %{status: 302} = result
    end
  end

  # ── require_authenticated_user/2 ──

  describe "require_authenticated_user/2" do
    test "returns conn unchanged when current_user is assigned" do
      user = user_fixture()

      conn =
        Plug.Test.conn(:get, "/admin/settings")
        |> Plug.Test.init_test_session(%{})
        |> assign(:current_user, user)
        |> put_private(:phoenix_router, TestAppWeb.Router)

      result = Auth.require_authenticated_user(conn, [])
      assert result == conn
    end

    test "redirects to log_in and halts when no current_user" do
      conn =
        Plug.Test.conn(:get, "/admin/settings")
        |> Plug.Test.init_test_session(%{})
        |> assign(:current_user, nil)
        |> put_private(:phoenix_router, TestAppWeb.Router)
        |> fetch_flash()

      result = Auth.require_authenticated_user(conn, [])
      assert result.halted == true
      assert %{status: 302} = result
      location = Plug.Conn.get_resp_header(result, "location") |> List.first()
      assert location =~ "/admin/log_in"
    end
  end
end
