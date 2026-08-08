defmodule Blank.Controllers.UeberauthCallbackControllerRoleMapperTest do
  use Blank.ConnCase

  alias Blank.Accounts
  alias Blank.Audit
  alias Blank.Audit.AuditLog
  alias Blank.Controllers.UeberauthCallbackController

  # ── Test mappers ──

  defmodule StaticMapper do
    @behaviour Blank.Authorization.RoleMapper

    @impl Blank.Authorization.RoleMapper
    def map_claims(_auth, _opts), do: [:system_admin, :member]
  end

  defmodule EmptyMapper do
    @behaviour Blank.Authorization.RoleMapper

    @impl Blank.Authorization.RoleMapper
    def map_claims(_auth, _opts), do: []
  end

  defmodule OptsAwareMapper do
    @behaviour Blank.Authorization.RoleMapper

    @impl Blank.Authorization.RoleMapper
    def map_claims(_auth, opts) do
      case Keyword.get(opts, :roles) do
        nil -> [:member]
        roles -> roles
      end
    end
  end

  defmodule InvalidRolesMapper do
    @behaviour Blank.Authorization.RoleMapper

    @impl Blank.Authorization.RoleMapper
    def map_claims(_auth, _opts), do: [:nonexistent_role]
  end

  defmodule MemberOnlyMapper do
    @behaviour Blank.Authorization.RoleMapper

    @impl Blank.Authorization.RoleMapper
    def map_claims(_auth, _opts), do: [:member]
  end

  # ── Helpers ──

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

  defp with_role_mapper(mapper_config, fun) do
    original = Application.get_env(:blank, :authorization, [])

    on_exit(fn ->
      Application.put_env(:blank, :authorization, original)
    end)

    updated = Keyword.put(original, :role_mapper, mapper_config)
    Application.put_env(:blank, :authorization, updated)

    fun.()
  end

  # ── No mapper configured ──

  describe "no mapper configured" do
    test "new user gets [:member]" do
      auth = ueberauth_auth(email: "no_mapper@example.com", uid: "uid_no_mapper_1")

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn

      user = Accounts.get_user_by_provider_and_uid(:google, "uid_no_mapper_1")
      assert user.roles == [:member]
    end

    test "existing user roles are NOT overwritten" do
      {:ok, existing_user} =
        Accounts.create_ueberauth_user(%{
          email: "keep_roles@example.com",
          name: "Keep Roles",
          provider: "google",
          external_uid: "uid_keep_roles_1",
          roles: [:system_admin]
        })

      auth =
        ueberauth_auth(
          email: "keep_roles@example.com",
          name: "Keep Roles Updated",
          uid: "uid_keep_roles_1"
        )

      conn =
        build_ueberauth_conn(%{ueberauth_auth: auth})
        |> UeberauthCallbackController.callback(%{"provider" => "google"})

      assert %{status: 302} = conn

      user = Accounts.get_user_by_provider_and_uid(:google, "uid_keep_roles_1")
      assert user.id == existing_user.id
      # Roles should NOT have changed
      assert user.roles == [:system_admin]
      # But email/name should be refreshed
      assert user.name == "Keep Roles Updated"
    end
  end

  # ── Mapper returns non-empty list ──

  describe "mapper returns non-empty list" do
    test "new user gets exactly the mapper's roles (no implicit :member appended)" do
      with_role_mapper({StaticMapper, []}, fn ->
        auth = ueberauth_auth(email: "static_mapper@example.com", uid: "uid_static_1")

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_static_1")
        # StaticMapper returns [:system_admin, :member]
        assert user.roles == [:system_admin, :member]
      end)
    end

    test "existing user roles are overwritten on subsequent login" do
      {:ok, _existing} =
        Accounts.create_ueberauth_user(%{
          email: "overwrite@example.com",
          name: "Overwrite Me",
          provider: "google",
          external_uid: "uid_overwrite_1",
          roles: [:member]
        })

      with_role_mapper({StaticMapper, []}, fn ->
        auth =
          ueberauth_auth(
            email: "overwrite@example.com",
            name: "Overwrite Me",
            uid: "uid_overwrite_1"
          )

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_overwrite_1")
        # StaticMapper returns [:system_admin, :member]
        assert user.roles == [:system_admin, :member]
      end)
    end

    test "update_roles is called with source: idp_claim_mapper" do
      {:ok, _existing} =
        Accounts.create_ueberauth_user(%{
          email: "source_test@example.com",
          name: "Source Test",
          provider: "google",
          external_uid: "uid_source_1",
          roles: [:member]
        })

      with_role_mapper({StaticMapper, []}, fn ->
        auth =
          ueberauth_auth(
            email: "source_test@example.com",
            name: "Source Test",
            uid: "uid_source_1"
          )

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        # Check audit log for roles_updated with correct source
        logs = Audit.list_all(where: [action: "accounts.roles_updated"])

        source_log =
          Enum.find(logs, fn log ->
            log.params["source"] == "idp_claim_mapper"
          end)

        assert source_log != nil
        assert source_log.params["roles"] == ["system_admin", "member"]
      end)
    end
  end

  # ── Mapper returns empty list (default-floor) ──

  describe "mapper returns empty list" do
    test "user gets [:member] (default-floor)" do
      with_role_mapper({EmptyMapper, []}, fn ->
        auth = ueberauth_auth(email: "empty_mapper@example.com", uid: "uid_empty_1")

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_empty_1")
        assert user.roles == [:member]
      end)
    end

    test "existing user gets [:member] floor on subsequent login" do
      {:ok, _existing} =
        Accounts.create_ueberauth_user(%{
          email: "empty_floor@example.com",
          name: "Empty Floor",
          provider: "google",
          external_uid: "uid_empty_floor_1",
          roles: [:system_admin]
        })

      with_role_mapper({EmptyMapper, []}, fn ->
        auth =
          ueberauth_auth(
            email: "empty_floor@example.com",
            name: "Empty Floor",
            uid: "uid_empty_floor_1"
          )

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_empty_floor_1")
        assert user.roles == [:member]
      end)
    end
  end

  # ── Mapper returns invalid roles ──

  describe "mapper returns invalid roles" do
    test "login fails with accounts.login_failed audit event" do
      with_role_mapper({InvalidRolesMapper, []}, fn ->
        auth =
          ueberauth_auth(email: "invalid_roles@example.com", uid: "uid_invalid_1")

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn
        location = get_resp_header(conn, "location") |> List.first()
        assert location == "/admin/log_in"

        # User should NOT have been created
        assert Accounts.get_user_by_provider_and_uid(:google, "uid_invalid_1") == nil

        # Check audit log
        logs = Audit.list_all(where: [action: "accounts.login_failed"])

        failed_log =
          Enum.find(logs, fn log ->
            log.params["reason"] == "invalid_roles_from_mapper"
          end)

        assert failed_log != nil
        assert failed_log.params["email"] == "invalid_roles@example.com"
        assert failed_log.params["provider"] == "google"
      end)
    end

    test "existing user login also fails with invalid roles" do
      {:ok, _existing} =
        Accounts.create_ueberauth_user(%{
          email: "existing_invalid@example.com",
          name: "Existing Invalid",
          provider: "google",
          external_uid: "uid_existing_invalid_1",
          roles: [:member]
        })

      with_role_mapper({InvalidRolesMapper, []}, fn ->
        auth =
          ueberauth_auth(
            email: "existing_invalid@example.com",
            name: "Existing Invalid",
            uid: "uid_existing_invalid_1"
          )

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn
        location = get_resp_header(conn, "location") |> List.first()
        assert location == "/admin/log_in"

        # User's roles should NOT have changed
        user = Accounts.get_user_by_provider_and_uid(:google, "uid_existing_invalid_1")
        assert user.roles == [:member]

        # Check audit log
        logs = Audit.list_all(where: [action: "accounts.login_failed"])

        failed_log =
          Enum.find(logs, fn log ->
            log.params["reason"] == "invalid_roles_from_mapper" and
              log.params["email"] == "existing_invalid@example.com"
          end)

        assert failed_log != nil
      end)
    end
  end

  # ── Config shapes ──

  describe "config accepts both {Module, opts} and plain Module" do
    test "{Module, opts} passes opts to mapper" do
      with_role_mapper({OptsAwareMapper, [roles: [:system_admin]]}, fn ->
        auth = ueberauth_auth(email: "opts_tuple@example.com", uid: "uid_opts_tuple_1")

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_opts_tuple_1")
        assert user.roles == [:system_admin]
      end)
    end

    test "plain Module (no-opts shorthand) works" do
      with_role_mapper(MemberOnlyMapper, fn ->
        auth = ueberauth_auth(email: "plain_module@example.com", uid: "uid_plain_1")

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth})
          |> UeberauthCallbackController.callback(%{"provider" => "google"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:google, "uid_plain_1")
        assert user.roles == [:member]
      end)
    end
  end

  # ── Uniform auth passing (no provider branching) ──

  describe "controller passes Ueberauth.Auth.t() uniformly" do
    test "mapper receives the full auth struct regardless of provider" do
      # We use OptsAwareMapper which just returns [:member] regardless of auth content.
      # The point is that the controller doesn't branch on provider — the mapper
      # receives the full Ueberauth.Auth.t() and does provider-specific extraction itself.
      with_role_mapper({OptsAwareMapper, [roles: [:member]]}, fn ->
        auth =
          ueberauth_auth(
            provider: :github,
            email: "uniform@example.com",
            uid: "uid_uniform_1"
          )

        conn =
          build_ueberauth_conn(%{ueberauth_auth: auth, _provider: "github"})
          |> UeberauthCallbackController.callback(%{"provider" => "github"})

        assert %{status: 302} = conn

        user = Accounts.get_user_by_provider_and_uid(:github, "uid_uniform_1")
        assert user.roles == [:member]
      end)
    end
  end
end
