defmodule Blank.RouterTest do
  use TestApp.DataCase

  describe "__blank_prefix__/0" do
    test "returns the configured admin prefix" do
      assert TestAppWeb.Router.__blank_prefix__() == "/admin"
    end
  end

  describe "__blank_modules__/0" do
    test "returns a list of admin page modules" do
      modules = TestAppWeb.Router.__blank_modules__()
      assert is_list(modules)
      assert not Enum.empty?(modules)
    end

    test "includes the PostLive admin page" do
      modules = TestAppWeb.Router.__blank_modules__()

      post_module =
        Enum.find_value(modules, fn {path, mod} ->
          if mod == TestAppWeb.Admin.PostLive, do: {path, mod}
        end)

      assert post_module != nil
    end

    test "returns the correct path for PostLive" do
      modules = TestAppWeb.Router.__blank_modules__()

      assert {"/posts", TestAppWeb.Admin.PostLive} in modules
    end
  end

  describe "routes" do
    test "defines the login route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/log_in", _opts = [])
    end

    test "defines the login POST route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "POST", "/admin/log_in", _opts = [])
    end

    test "defines the home route" do
      assert %{} = Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin", _opts = [])
    end

    test "defines the profile route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/profile", _opts = [])
    end

    test "defines the settings route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/settings", _opts = [])
    end

    test "defines the audit route" do
      assert %{} = Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/audit", _opts = [])
    end

    test "defines the download route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/download", _opts = [])
    end

    test "defines the qr code route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/qrcode", _opts = [])
    end

    test "defines the admin pages route" do
      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/admins", _opts = [])
    end

    test "defines the posts routes" do
      assert %{} = Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/posts", _opts = [])

      assert %{} =
               Phoenix.Router.route_info(TestAppWeb.Router, "GET", "/admin/posts/new", _opts = [])

      assert %{} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/import",
                 _opts = []
               )

      assert %{} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/export",
                 _opts = []
               )
    end

    test "defines the posts show route" do
      assert %{path_params: %{"id" => _}} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/1",
                 _opts = []
               )
    end

    test "defines the posts edit route" do
      assert %{path_params: %{"id" => _}} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/1/edit",
                 _opts = []
               )
    end

    test "defines the ueberauth request route" do
      assert %{plug: Ueberauth, plug_opts: :request} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/auth/github",
                 _opts = []
               )
    end

    test "defines the ueberauth callback route" do
      assert %{plug: Blank.Controllers.UeberauthCallbackController, plug_opts: :callback} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/auth/github/callback",
                 _opts = []
               )
    end

    test "defines the logout route" do
      assert %{} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "DELETE",
                 "/admin/log_out",
                 _opts = []
               )
    end
  end

  describe "pipeline setup" do
    test "unauthenticated routes pipe through redirect_if_user_is_authenticated" do
      assert %{pipe_through: pipe_through} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/log_in",
                 _opts = []
               )

      assert :redirect_if_user_is_authenticated in pipe_through
    end

    test "authenticated routes pipe through require_authenticated_user" do
      assert %{pipe_through: pipe_through} =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin",
                 _opts = []
               )

      assert :require_authenticated_user in pipe_through
    end

    test "all authenticated routes pipe through blank_browser" do
      routes = [
        {"GET", "/admin"},
        {"GET", "/admin/profile"},
        {"GET", "/admin/settings"},
        {"GET", "/admin/audit"},
        {"DELETE", "/admin/log_out"}
      ]

      for {method, path} <- routes do
        assert %{pipe_through: pipe_through} =
                 Phoenix.Router.route_info(TestAppWeb.Router, method, path, _opts = [])

        assert :blank_browser in pipe_through
      end
    end
  end

  describe "__options__/1" do
    test "returns default session name when no options given" do
      {session_name, session_opts} = Blank.Router.__options__([])
      assert session_name == :blank_admin_panel
      assert session_opts[:root_layout] == {Blank.LayoutView, :root}
    end

    test "uses custom live_session_name when provided" do
      {session_name, _session_opts} = Blank.Router.__options__(live_session_name: :my_custom)
      assert session_name == :my_custom
    end

    test "includes default on_mount hooks" do
      {_session_name, session_opts} = Blank.Router.__options__([])
      on_mount = session_opts[:on_mount]

      assert Enum.any?(on_mount, fn
               {Blank.Plugs.Auth, :ensure_authenticated} -> true
               _ -> false
             end)

      assert Enum.any?(on_mount, fn
               {Blank.Authorization, :authorize} -> true
               _ -> false
             end)

      assert Blank.Nav in on_mount
      assert Blank.Audit.Context in on_mount
    end

    test "merges custom on_mount hooks with defaults" do
      custom_hook = {SomeModule, :custom_hook}
      {_session_name, session_opts} = Blank.Router.__options__(on_mount: [custom_hook])
      on_mount = session_opts[:on_mount]

      assert custom_hook in on_mount
      assert {Blank.Plugs.Auth, :ensure_authenticated} in on_mount
    end
  end

  describe "live views" do
    test "login route points to LoginLive" do
      assert %{
               phoenix_live_view: {Blank.Pages.LoginLive, :new, _params, _extra}
             } =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/log_in",
                 _opts = []
               )
    end

    test "home route points to HomeLive" do
      assert %{
               phoenix_live_view: {Blank.Pages.HomeLive, :home, _params, _extra}
             } =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin",
                 _opts = []
               )
    end

    test "profile route points to ProfileLive" do
      assert %{
               phoenix_live_view: {Blank.Pages.ProfileLive, :profile, _params, _extra}
             } =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/profile",
                 _opts = []
               )
    end

    test "posts show route points to PostLive with show action" do
      assert %{
               phoenix_live_view:
                 {TestAppWeb.Admin.PostLive, :show, _params, %{extra: %{on_mount: on_mount}}}
             } =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/1",
                 _opts = []
               )

      assert Enum.any?(on_mount, fn
               %{id: {Blank.Plugs.Auth, :ensure_authenticated}} -> true
               _ -> false
             end)
    end

    test "posts edit route points to PostLive with edit action" do
      assert %{
               phoenix_live_view: {TestAppWeb.Admin.PostLive, :edit, _params, _extra}
             } =
               Phoenix.Router.route_info(
                 TestAppWeb.Router,
                 "GET",
                 "/admin/posts/1/edit",
                 _opts = []
               )
    end
  end
end
