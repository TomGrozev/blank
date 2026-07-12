defmodule Blank.Components.AuditLogComponentTest do
  use Blank.LiveViewCase

  alias Blank.Audit.AuditLog
  alias Blank.Components.AuditLogComponent

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting the audit log page renders the component with logs", %{conn: conn} do
    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 1})
    Blank.Audit.log!(AuditLog.system(), "posts.update", %{item_id: 2})

    {:ok, _view, html} = live(conn, "/admin/audit")

    assert html =~ "Audit Logs"
    assert html =~ "Displays the activity log"
  end

  test "component updates when new log is broadcast", %{conn: conn} do
    Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

    {:ok, view, _html} = live(conn, "/admin/audit")

    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 99})

    Process.sleep(100)

    html = render(view)
    assert html =~ "Audit Logs"
  end

  describe "audit_icon/1" do
    test "returns correct icon for accounts.login" do
      log = %{AuditLog.system() | action: "accounts.login"}
      assert AuditLogComponent.audit_icon(log) == "hero-arrow-right-end-on-rectangle"
    end

    test "returns correct icon for accounts.login_failed" do
      log = %{AuditLog.system() | action: "accounts.login_failed"}
      assert AuditLogComponent.audit_icon(log) == "hero-x-circle"
    end

    test "returns correct icon for accounts.logout" do
      log = %{AuditLog.system() | action: "accounts.logout"}
      assert AuditLogComponent.audit_icon(log) == "hero-arrow-left-start-on-rectangle"
    end

    test "returns correct icon for accounts.user_created" do
      log = %{AuditLog.system() | action: "accounts.user_created"}
      assert AuditLogComponent.audit_icon(log) == "hero-user-plus"
    end

    test "returns correct icon for *.create" do
      log = %{AuditLog.system() | action: "*.create"}
      assert AuditLogComponent.audit_icon(log) == "hero-plus"
    end

    test "returns correct icon for *.create_multiple" do
      log = %{AuditLog.system() | action: "*.create_multiple"}
      assert AuditLogComponent.audit_icon(log) == "hero-plus"
    end

    test "returns correct icon for *.update" do
      log = %{AuditLog.system() | action: "*.update"}
      assert AuditLogComponent.audit_icon(log) == "hero-pencil"
    end

    test "returns correct icon for *.update_multiple" do
      log = %{AuditLog.system() | action: "*.update_multiple"}
      assert AuditLogComponent.audit_icon(log) == "hero-pencil"
    end

    test "returns correct icon for *.delete" do
      log = %{AuditLog.system() | action: "*.delete"}
      assert AuditLogComponent.audit_icon(log) == "hero-trash"
    end

    test "returns correct icon for *.delete_all" do
      log = %{AuditLog.system() | action: "*.delete_all"}
      assert AuditLogComponent.audit_icon(log) == "hero-trash"
    end

    test "returns correct icon for *.other (unknown star action)" do
      log = %{AuditLog.system() | action: "*.other"}
      assert AuditLogComponent.audit_icon(log) == "hero-information-circle-solid"
    end

    test "converts concrete action to star action" do
      log = %{AuditLog.system() | action: "posts.create"}
      assert AuditLogComponent.audit_icon(log) == "hero-plus"
    end

    test "converts concrete update action to star action" do
      log = %{AuditLog.system() | action: "posts.update"}
      assert AuditLogComponent.audit_icon(log) == "hero-pencil"
    end

    test "converts concrete delete action to star action" do
      log = %{AuditLog.system() | action: "posts.delete"}
      assert AuditLogComponent.audit_icon(log) == "hero-trash"
    end
  end

  describe "audit_colour/1" do
    test "returns emerald for accounts.* actions" do
      log = %{AuditLog.system() | action: "accounts.login"}
      assert AuditLogComponent.audit_colour(log) == "bg-emerald-400"
    end

    test "returns emerald for accounts.logout" do
      log = %{AuditLog.system() | action: "accounts.logout"}
      assert AuditLogComponent.audit_colour(log) == "bg-emerald-400"
    end

    test "returns blue for *.create" do
      log = %{AuditLog.system() | action: "*.create"}
      assert AuditLogComponent.audit_colour(log) == "bg-blue-400"
    end

    test "returns blue for *.create_multiple" do
      log = %{AuditLog.system() | action: "*.create_multiple"}
      assert AuditLogComponent.audit_colour(log) == "bg-blue-400"
    end

    test "returns sky for *.update" do
      log = %{AuditLog.system() | action: "*.update"}
      assert AuditLogComponent.audit_colour(log) == "bg-sky-400"
    end

    test "returns sky for *.update_multiple" do
      log = %{AuditLog.system() | action: "*.update_multiple"}
      assert AuditLogComponent.audit_colour(log) == "bg-sky-400"
    end

    test "returns rose for *.delete" do
      log = %{AuditLog.system() | action: "*.delete"}
      assert AuditLogComponent.audit_colour(log) == "bg-rose-400"
    end

    test "returns rose for *.delete_all" do
      log = %{AuditLog.system() | action: "*.delete_all"}
      assert AuditLogComponent.audit_colour(log) == "bg-rose-400"
    end

    test "returns gray for *.other (unknown star action)" do
      log = %{AuditLog.system() | action: "*.other"}
      assert AuditLogComponent.audit_colour(log) == "bg-gray-400"
    end

    test "converts concrete action to star action for colour" do
      log = %{AuditLog.system() | action: "posts.create"}
      assert AuditLogComponent.audit_colour(log) == "bg-blue-400"
    end

    test "converts concrete update to star action for colour" do
      log = %{AuditLog.system() | action: "posts.update"}
      assert AuditLogComponent.audit_colour(log) == "bg-sky-400"
    end

    test "converts concrete delete to star action for colour" do
      log = %{AuditLog.system() | action: "posts.delete"}
      assert AuditLogComponent.audit_colour(log) == "bg-rose-400"
    end
  end

  describe "audit_text/4" do
    test "accounts.login for system user" do
      log = %{AuditLog.system() | action: "accounts.login", params: %{}}
      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged in"
    end

    test "accounts.login for ueberauth with provider" do
      log = %{
        AuditLog.system()
        | action: "accounts.login",
          params: %{"type" => "ueberauth", "provider" => "github"}
      }

      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged in via"
    end

    test "accounts.login with atom params" do
      log = %{
        AuditLog.system()
        | action: "accounts.login",
          params: %{type: "ueberauth", provider: "google"}
      }

      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged in via"
    end

    test "accounts.login_failed for system" do
      log = %{
        AuditLog.system()
        | action: "accounts.login_failed",
          params: %{"email" => "test@example.com", "reason" => "invalid"}
      }

      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "failed login for test@example.com"
      assert rendered =~ "invalid"
    end

    test "accounts.login_failed with provider" do
      log = %{
        AuditLog.system()
        | action: "accounts.login_failed",
          params: %{"email" => "test@example.com", "reason" => "invalid", "provider" => "github"}
      }

      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "failed login for test@example.com"
      assert rendered =~ "Github"
    end

    test "accounts.login_failed with atom params" do
      log = %{
        AuditLog.system()
        | action: "accounts.login_failed",
          params: %{email: "x@y.com", reason: "bad"}
      }

      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "failed login for x@y.com"
    end

    test "accounts.logout for system" do
      log = %{AuditLog.system() | action: "accounts.logout", params: %{}}
      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged out"
    end

    test "accounts.user_created for system" do
      log = %{AuditLog.system() | action: "accounts.user_created", params: %{}}
      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "created a user"
    end

    test "*.create with item_id" do
      log = %{AuditLog.system() | action: "*.create", params: %{"item_id" => 42}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "created a Post"
      assert rendered =~ "42"
    end

    test "*.create_multiple with item_ids" do
      log = %{AuditLog.system() | action: "*.create_multiple", params: %{"item_ids" => [1, 2, 3]}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Comment")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "created multiple Comment"
      assert rendered =~ "1, 2, 3"
    end

    test "*.update with item_id" do
      log = %{AuditLog.system() | action: "*.update", params: %{"item_id" => 10}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "updated a Post"
      assert rendered =~ "10"
    end

    test "*.update_multiple with item_ids" do
      log = %{AuditLog.system() | action: "*.update_multiple", params: %{"item_ids" => [5, 6]}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Tag")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "updated multiple Tag"
    end

    test "*.delete with item_id" do
      log = %{AuditLog.system() | action: "*.delete", params: %{"item_id" => 7}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "deleted a Post"
      assert rendered =~ "7"
    end

    test "*.delete_all" do
      log = %{AuditLog.system() | action: "*.delete_all", params: %{}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Tag")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "deleted all Tag"
    end

    test "concrete action is converted to star action" do
      log = %{AuditLog.system() | action: "posts.create", params: %{"item_id" => 1}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "created a Post"
    end

    test "concrete update action converts to star" do
      log = %{AuditLog.system() | action: "posts.update", params: %{"item_id" => 5}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "updated a Post"
    end

    test "concrete delete action converts to star" do
      log = %{AuditLog.system() | action: "posts.delete", params: %{"item_id" => 3}}
      html = AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "deleted a Post"
    end

    test "raises for unknown star action without type" do
      log = %{AuditLog.system() | action: "*.unknown_action", params: %{}}

      assert_raise ArgumentError, ~r/invalid action supplied/, fn ->
        AuditLogComponent.audit_text(log, "/admin", %{})
      end
    end

    test "raises for unknown star action with type" do
      log = %{AuditLog.system() | action: "*.unknown_action", params: %{}}

      assert_raise ArgumentError, ~r/Post\.unknown_action/, fn ->
        AuditLogComponent.audit_text(log, "/admin", %{}, "Post")
      end
    end

    test "user log with schema links generates link" do
      user = user_fixture()
      log = %{AuditLog.system() | action: "accounts.login", params: %{}, user: user}
      schema_links = %{Blank.Accounts.User => "/admin/users"}
      html = AuditLogComponent.audit_text(log, "/admin", schema_links)
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged in"
      assert rendered =~ "/admin/users/"
    end

    test "user log without schema_links does not generate link" do
      user = user_fixture()
      log = %{AuditLog.system() | action: "accounts.login", params: %{}, user: user}
      html = AuditLogComponent.audit_text(log, "/admin", %{})
      rendered = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()
      assert rendered =~ "logged in"
    end
  end
end
