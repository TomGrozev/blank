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
      assert length(modules) > 0
    end

    test "includes the PostLive admin page" do
      modules = TestAppWeb.Router.__blank_modules__()

      post_module =
        Enum.find_value(modules, fn {path, mod} ->
          if mod == TestAppWeb.Admin.PostLive, do: {path, mod}
        end)

      assert post_module != nil
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
end
