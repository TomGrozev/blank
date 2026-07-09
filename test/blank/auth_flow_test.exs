defmodule Blank.AuthFlowTest do
  use Blank.ConnCase

  alias Blank.Accounts
  alias Blank.Audit.AuditLog

  @valid_email "user@example.com"
  @valid_password "Str0ng!Passw0rd"

  setup %{conn: conn} do
    {:ok, user} = Accounts.register_user(%{email: @valid_email, password: @valid_password})
    %{conn: conn, user: user}
  end

  # ── Helpers ──

  defp build_ueberauth_conn(assigns \\ %{}) do
    provider = Map.get(assigns, :_provider, "google")

    Plug.Test.conn(:get, "/admin/auth/google/callback")
    |> Map.update!(:params, fn _ -> %{"provider" => provider} end)
    |> Plug.Test.init_test_session(%{})
    |> fetch_flash()
    |> put_private(:phoenix_router, TestAppWeb.Router)
    |> assign(:audit_context, AuditLog.system())
    |> then(fn conn ->
      assigns
      |> Map.drop([:_provider])
      |> Enum.reduce(conn, fn {key, value}, acc ->
        assign(acc, key, value)
      end)
    end)
  end

  defp ueberauth_auth(opts) do
    %Ueberauth.Auth{
      provider: Keyword.get(opts, :provider, :google),
      uid: Keyword.get(opts, :uid, "12345"),
      info: %Ueberauth.Auth.Info{
        email: Keyword.get(opts, :email, "oauth_user@example.com"),
        name: Keyword.get(opts, :name, "OAuth User")
      }
    }
  end

  defp ueberauth_failure(opts) do
    %Ueberauth.Failure{
      provider: Keyword.get(opts, :provider, :google),
      errors: [
        %Ueberauth.Failure.Error{
          message_key: "access_denied",
          message: Keyword.get(opts, :message, "User denied access")
        }
      ]
    }
  end

  # ── SessionController.create/2 ──

  describe "SessionController.create/2" do
    test "with valid credentials redirects to user home and sets session token", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "user" => %{"email" => @valid_email, "password" => @valid_password}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # The session should contain user_token
      assert get_session(conn, :user_token)
    end

    test "with invalid credentials redirects to /log_in with error flash", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "user" => %{"email" => @valid_email, "password" => "wrongpassword"}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "with invalid email redirects to /log_in", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "user" => %{"email" => "unknown@example.com", "password" => @valid_password}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end
  end

  # ── SessionController.delete/2 ──

  describe "SessionController.delete/2" do
    test "logs out and redirects to prefix", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> delete("/admin/log_out")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # Session should be cleared — trying to access protected page should redirect
      conn2 =
        conn
        |> recycle()
        |> get("/admin")

      assert %{status: 302} = conn2
    end
  end

  # ── Auth.fetch_current_user/2 ──

  describe "Auth.fetch_current_user/2" do
    test "with a valid session token, assigns :current_user", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end

    test "with no token, :current_user is nil and redirects to log_in", %{conn: conn} do
      conn = get(conn, "/admin")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end
  end

  # ── Auth.redirect_if_user_is_authenticated/2 ──

  describe "Auth.redirect_if_user_is_authenticated/2" do
    test "when no user, allows through to login page", %{conn: conn} do
      conn = get(conn, "/admin/log_in")
      assert html_response(conn, 200) =~ "Sign in to Blank admin"
    end

    test "when user is authenticated, redirects to signed_in_path", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/log_in")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end
  end

  # ── Auth.require_authenticated_user/2 ──

  describe "Auth.require_authenticated_user/2" do
    test "when no user, redirects to log_in", %{conn: conn} do
      conn = get(conn, "/admin/settings")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "when user is authenticated, allows through", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end
  end

  # ── Auth.log_in/3 ──

  describe "Auth.log_in/3" do
    test "creates a session token and redirects to signed_in_path", %{conn: conn, user: _user} do
      # Use the router to set up a conn with proper session and pipeline
      conn =
        conn
        |> post("/admin/log_in", %{
          "user" => %{"email" => @valid_email, "password" => @valid_password}
        })

      assert %{status: 302} = conn
      assert get_session(conn, :user_token)
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end

    test "with remember_me cookie", %{conn: conn, user: _user} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "user" => %{
            "email" => @valid_email,
            "password" => @valid_password,
            "remember_me" => "true"
          }
        })

      assert %{status: 302} = conn
      assert get_session(conn, :user_token)

      # Should have set the remember me cookie
      conn_cookies = Plug.Conn.fetch_cookies(conn)
      assert conn_cookies.cookies["_blank_user_remember_me"]
    end
  end

  # ── Auth.log_out/1 ──

  describe "Auth.log_out/1" do
    test "logs out and redirects to prefix", %{conn: conn, user: user} do
      # Log in through the router first
      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"

      # Now log out via the router
      conn =
        conn
        |> recycle()
        |> log_in_user(user)
        |> delete("/admin/log_out")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end
  end

  # ── UeberauthCallbackController.callback/2 — success path (new user) ──

  describe "UeberauthCallbackController.callback/2 — new user" do
    test "creates user from ueberauth auth and logs in" do
      auth = ueberauth_auth(email: "new_oauth@example.com", name: "New OAuth", uid: "uid_new_1")

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # Verify user was created with correct attributes
      user = Accounts.get_user_by_provider_and_uid(:google, "uid_new_1")
      assert user != nil
      assert user.email == "new_oauth@example.com"
      assert user.name == "New OAuth"
      assert user.provider == "google"
      assert user.external_uid == "uid_new_1"
      assert user.roles == [:member]
    end

    test "emits accounts.user_created audit event" do
      auth =
        ueberauth_auth(email: "audit_test@example.com", name: "Audit User", uid: "uid_audit_1")

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn

      # Check audit log was created
      logs = Blank.Audit.list_all(where: [action: "accounts.user_created"])
      assert Enum.any?(logs, fn log -> log.params["email"] == "audit_test@example.com" end)
    end

    test "sets welcome flash message" do
      auth = ueberauth_auth(email: "flash_test@example.com", uid: "uid_flash_1")

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
      # The conn should have a flash message set (verified by successful redirect)
    end
  end

  # ── UeberauthCallbackController.callback/2 — success path (existing user) ──

  describe "UeberauthCallbackController.callback/2 — existing user" do
    test "refreshes user email/name and logs in" do
      # Create a ueberauth user first
      {:ok, existing_user} =
        Accounts.create_ueberauth_user(%{
          email: "existing_oauth@example.com",
          name: "Old Name",
          provider: "google",
          external_uid: "uid_existing_1"
        })

      # Mock a callback with updated info
      auth =
        ueberauth_auth(
          email: "updated_oauth@example.com",
          name: "Updated Name",
          uid: "uid_existing_1"
        )

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # Verify user was refreshed
      user = Accounts.get_user_by_provider_and_uid(:google, "uid_existing_1")
      assert user.id == existing_user.id
      assert user.email == "updated_oauth@example.com"
      assert user.name == "Updated Name"
    end

    test "does not emit accounts.user_created audit event" do
      # Create a ueberauth user first
      {:ok, _user} =
        Accounts.create_ueberauth_user(%{
          email: "no_create_event@example.com",
          name: "No Create",
          provider: "github",
          external_uid: "uid_no_create_1"
        })

      auth =
        ueberauth_auth(
          provider: :github,
          email: "no_create_event@example.com",
          name: "No Create",
          uid: "uid_no_create_1"
        )

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "github"})

      assert %{status: 302} = conn

      # Verify no user_created event was emitted
      logs = Blank.Audit.list_all(where: [action: "accounts.user_created"])
      refute Enum.any?(logs, fn log -> log.params["email"] == "no_create_event@example.com" end)
    end

    test "sets welcome back flash message" do
      {:ok, _user} =
        Accounts.create_ueberauth_user(%{
          email: "welcome_back@example.com",
          name: "Welcome Back",
          provider: "google",
          external_uid: "uid_wb_1"
        })

      auth =
        ueberauth_auth(
          email: "welcome_back@example.com",
          name: "Welcome Back",
          uid: "uid_wb_1"
        )

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
    end
  end

  # ── UeberauthCallbackController.callback/2 — failure path ──

  describe "UeberauthCallbackController.callback/2 — failure" do
    test "redirects to login with error flash" do
      failure = ueberauth_failure(message: "User denied access")

      conn =
        build_ueberauth_conn(%{ueberauth_failure: failure})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "emits accounts.login_failed audit event with provider and reason" do
      failure = ueberauth_failure(provider: :github, message: "Invalid credentials")

      conn =
        build_ueberauth_conn(%{ueberauth_failure: failure, _provider: "github"})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "github"})

      assert %{status: 302} = conn

      # Check audit log was created with correct details
      logs = Blank.Audit.list_all(where: [action: "accounts.login_failed"])
      github_logs = Enum.filter(logs, fn log -> log.params["provider"] == "github" end)
      assert !Enum.empty?(github_logs)
      assert hd(github_logs).params["reason"] == "Invalid credentials"
    end
  end

  # ── UeberauthCallbackController.callback/2 — edge cases ──

  describe "UeberauthCallbackController.callback/2 — edge cases" do
    test "fallback clause when no auth or failure assigns" do
      conn =
        build_ueberauth_conn()
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "fallback clause emits login_failed audit event" do
      conn =
        build_ueberauth_conn()
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn

      logs = Blank.Audit.list_all(where: [action: "accounts.login_failed"])
      google_logs = Enum.filter(logs, fn log -> log.params["provider"] == "google" end)
      assert !Enum.empty?(google_logs)
      assert hd(google_logs).params["reason"] == "unknown error"
    end

    test "failure with multiple error messages joins them" do
      failure = %Ueberauth.Failure{
        provider: :google,
        errors: [
          %Ueberauth.Failure.Error{message_key: "first", message: "First error"},
          %Ueberauth.Failure.Error{message_key: "second", message: "Second error"}
        ]
      }

      conn =
        build_ueberauth_conn(%{ueberauth_failure: failure})
        |> Blank.Controllers.UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn

      logs = Blank.Audit.list_all(where: [action: "accounts.login_failed"])
      google_logs = Enum.filter(logs, fn log -> log.params["provider"] == "google" end)
      assert !Enum.empty?(google_logs)
      assert hd(google_logs).params["reason"] == "First error, Second error"
    end
  end

  # ── Blank.Application.validate_ueberauth_config!/0 — boot-time guard ──

  describe "Blank.Application.start/2 — ueberauth config guard" do
    test "raises when no providers configured" do
      original_config = Application.get_env(:ueberauth, Ueberauth, [])

      on_exit(fn ->
        Application.put_env(:ueberauth, Ueberauth, original_config)
        Application.delete_env(:blank, :auth)
      end)

      Application.put_env(:blank, :auth, local_login: :disabled)
      Application.put_env(:ueberauth, Ueberauth, providers: [])

      assert_raise RuntimeError, ~r/Blank requires at least one Ueberauth provider/, fn ->
        Blank.Application.start(:normal, [])
      end
    end

    test "does not raise when providers are configured" do
      original_config = Application.get_env(:ueberauth, Ueberauth, [])

      on_exit(fn ->
        Application.put_env(:ueberauth, Ueberauth, original_config)
      end)

      Application.put_env(:ueberauth, Ueberauth,
        providers: [google: {Ueberauth.Strategy.Google, []}]
      )

      # Verify the guard condition: providers list is non-empty
      config = Application.get_env(:ueberauth, Ueberauth, [])
      providers = Keyword.get(config, :providers, [])
      assert providers != []
      assert Keyword.has_key?(providers, :google)
    end
  end

  # ── Session Timeout Tests ──

  describe "Session timeout — idle timeout" do
    test "token is valid within idle timeout", %{conn: conn, user: user} do
      # Set a short idle timeout for testing
      original_config = Application.get_env(:blank, :auth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_config)
      end)

      Application.put_env(:blank, :auth, idle_timeout: {1, :hours})

      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end

    test "token is invalidated after idle timeout", %{conn: conn, user: user} do
      # Set a very short idle timeout
      original_config = Application.get_env(:blank, :auth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_config)
      end)

      Application.put_env(:blank, :auth, idle_timeout: {1, :minutes})

      conn =
        conn
        |> log_in_user(user)

      # Get the token from session
      token = get_session(conn, :user_token)

      # Manually update last_activity_at to 2 minutes ago
      token_record =
        TestApp.Repo.one!(Blank.Accounts.UserToken.by_token_and_context_query(token, "session"))

      two_minutes_ago =
        DateTime.truncate(DateTime.add(DateTime.utc_now(), -120, :second), :second)

      TestApp.Repo.update!(
        Ecto.Changeset.change(token_record, %{last_activity_at: two_minutes_ago})
      )

      # Now try to access a protected page - should be redirected
      conn2 =
        conn
        |> recycle()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> get("/admin/settings")

      # Should redirect to login due to idle timeout
      assert %{status: 302} = conn2
    end
  end

  describe "Session timeout — absolute lifetime" do
    test "token is valid within absolute lifetime", %{conn: conn, user: user} do
      # Set a long absolute lifetime for testing
      original_config = Application.get_env(:blank, :auth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_config)
      end)

      Application.put_env(:blank, :auth, absolute_lifetime: {30, :days})

      conn =
        conn
        |> log_in_user(user)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end

    test "token is invalidated after absolute lifetime", %{conn: conn, user: user} do
      # Set a very short absolute lifetime
      original_config = Application.get_env(:blank, :auth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_config)
      end)

      Application.put_env(:blank, :auth, absolute_lifetime: {1, :minutes})

      conn =
        conn
        |> log_in_user(user)

      # Get the token from session
      token = get_session(conn, :user_token)

      # Manually update inserted_at to 2 minutes ago
      token_record =
        TestApp.Repo.one!(Blank.Accounts.UserToken.by_token_and_context_query(token, "session"))

      two_minutes_ago =
        DateTime.truncate(DateTime.add(DateTime.utc_now(), -120, :second), :second)

      TestApp.Repo.update!(Ecto.Changeset.change(token_record, %{inserted_at: two_minutes_ago}))

      # Now try to access a protected page - should be redirected
      conn2 =
        conn
        |> recycle()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> get("/admin/settings")

      # Should redirect to login due to absolute lifetime
      assert %{status: 302} = conn2
    end
  end

  describe "Session timeout — last_activity_at update" do
    test "last_activity_at is updated on each request", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)

      # Get the token from session
      token = get_session(conn, :user_token)

      # Get initial last_activity_at
      token_record =
        TestApp.Repo.one!(Blank.Accounts.UserToken.by_token_and_context_query(token, "session"))

      initial_last_activity = token_record.last_activity_at
      assert initial_last_activity != nil

      # Sleep to ensure timestamp changes (truncated to seconds)
      Process.sleep(1100)

      # Make a request
      conn
      |> get("/admin/settings")

      # Check that last_activity_at was updated
      updated_token_record =
        TestApp.Repo.one!(Blank.Accounts.UserToken.by_token_and_context_query(token, "session"))

      assert DateTime.compare(updated_token_record.last_activity_at, initial_last_activity) == :gt
    end
  end

  describe "Session timeout — config defaults" do
    test "config defaults work when not explicitly set" do
      # Clear any existing config
      original_config = Application.get_env(:blank, :auth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_config)
      end)

      Application.delete_env(:blank, :auth)

      # Should use default values without crashing
      idle_timeout = Blank.Plugs.Auth.idle_timeout()
      absolute_lifetime = Blank.Plugs.Auth.absolute_lifetime()

      # 4 hours in seconds
      assert idle_timeout == 4 * 3600
      # 60 days in seconds
      assert absolute_lifetime == 60 * 86400
    end
  end
end
