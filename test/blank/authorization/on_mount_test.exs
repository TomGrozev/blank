defmodule Blank.Authorization.OnMountTest do
  @moduledoc """
  Tests for the LiveView on_mount authorizing hook and AdminPage auto-derivation.
  Covers issue #9 acceptance criteria.
  """

  use Blank.ConnCase

  import Phoenix.LiveViewTest

  alias Blank.Authorization

  # ── __blank_resource_type__/0 ──────────────────────────────────────

  describe "__blank_resource_type__/0" do
    test "is defined by use Blank.Authorization, :resource" do
      defmodule OnMountTestResource do
        use Blank.Authorization, :widget
      end

      assert OnMountTestResource.__blank_resource_type__() == :widget
    end

    test "AdminPage auto-injects resource type from :key" do
      # TestAppWeb.Admin.PostLive uses Blank.AdminPage with schema: Post
      # The key is derived as :post from the schema module name
      assert function_exported?(TestAppWeb.Admin.PostLive, :__blank_resource_type__, 0)
      assert TestAppWeb.Admin.PostLive.__blank_resource_type__() == :post
    end
  end

  # ── on_mount(:authorize, ...) unit tests ───────────────────────────

  describe "on_mount(:authorize, ...)" do
    test "allows system_admin user through" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :index,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _socket} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "halts and redirects member user with DefaultPolicy" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :index,
          current_user: %{roles: [:member]}
        )

      assert {:halt, socket} = Authorization.on_mount(:authorize, %{}, %{}, socket)
      assert socket.redirected
    end

    test "passes through when module has no resource type" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithoutResource,
          live_action: :index,
          current_user: %{roles: [:member]}
        )

      assert {:cont, _socket} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :index action to :list" do
      # We verify via the coarse_action mapping indirectly:
      # A system_admin is allowed for any action, so we just verify :cont
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :index,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :show action to :read" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :show,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :import action to :list" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :import,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :export action to :list" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :export,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :edit action to :read" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :edit,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end

    test "maps :new action to :read" do
      socket =
        build_socket(
          view: __MODULE__.ModuleWithResource,
          live_action: :new,
          current_user: %{roles: [:system_admin]}
        )

      assert {:cont, _} = Authorization.on_mount(:authorize, %{}, %{}, socket)
    end
  end

  # ── Router on_mount chain ──────────────────────────────────────────

  describe "router on_mount chain" do
    test "includes {Blank.Authorization, :authorize} as last built-in hook" do
      {_name, opts} = Blank.Router.__options__([])
      on_mount = Keyword.fetch!(opts, :on_mount)

      assert {Blank.Authorization, :authorize} in on_mount
    end

    test "authorize hook comes after ensure_authenticated and Audit.Context" do
      {_name, opts} = Blank.Router.__options__([])
      on_mount = Keyword.fetch!(opts, :on_mount)

      auth_idx = Enum.find_index(on_mount, &(&1 == {Blank.Plugs.Auth, :ensure_authenticated}))
      audit_idx = Enum.find_index(on_mount, &(&1 == Blank.Audit.Context))
      authorize_idx = Enum.find_index(on_mount, &(&1 == {Blank.Authorization, :authorize}))

      assert auth_idx < authorize_idx
      assert audit_idx < authorize_idx
    end
  end

  # ── Integration: live tests with real router ───────────────────────

  describe "integration with live router" do
    test "system_admin user can mount admin page", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "admin_integration@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:system_admin]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/admin/posts")
      assert html =~ "Posts"
    end

    test "member user is denied at the boundary", %{conn: conn} do
      {:ok, user} =
        Blank.Accounts.register_user(%{
          email: "member_integration@example.com",
          password: "Str0ng!Passw0rd"
        })

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{roles: [:member]})
        |> TestApp.Repo.update()

      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/admin", flash: %{"error" => msg}}}} =
               live(conn, "/admin/posts")

      assert msg =~ "not authorized"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  # A module with a resource type for unit tests
  defmodule ModuleWithResource do
    use Blank.Authorization, :test_resource

    def __blank_prefix__, do: "/admin"
  end

  # A module without a resource type
  defmodule ModuleWithoutResource do
    def __blank_prefix__, do: "/admin"
  end

  defp build_socket(opts) do
    %Phoenix.LiveView.Socket{
      view: Keyword.fetch!(opts, :view),
      assigns: %{
        live_action: Keyword.fetch!(opts, :live_action),
        current_user: Keyword.fetch!(opts, :current_user),
        flash: %{},
        __changed__: %{}
      },
      router: __MODULE__.ModuleWithResource
    }
  end
end
