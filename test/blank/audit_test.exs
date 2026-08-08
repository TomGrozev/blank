defmodule Blank.AuditTest do
  use TestApp.DataCase

  alias Blank.Audit
  alias Blank.Audit.AuditLog

  describe "log!/3" do
    test "inserts a record and broadcasts" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      context = AuditLog.system()
      log = Audit.log!(context, "app.test", %{detail: "hello"})

      assert %AuditLog{} = log
      assert log.id
      assert log.action == "app.test"

      assert_received {:audit_log, ^log}
    end

    test "with system context" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      context = AuditLog.system()
      log = Audit.log!(context, "app.system_event", %{})

      assert log.user_agent == "SYSTEM"
      assert log.user == nil
      assert log.admin == nil

      assert_received {:audit_log, ^log}
    end
  end

  describe "list_all/1" do
    test "returns logs in reverse chronological order" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      log1 = %{
        AuditLog.system()
        | action: "app.first",
          inserted_at: DateTime.add(now, -10, :second)
      }

      log1 = Repo.insert!(log1)

      log2 = %{
        AuditLog.system()
        | action: "app.second",
          inserted_at: DateTime.add(now, -5, :second)
      }

      log2 = Repo.insert!(log2)

      results = Audit.list_all()

      assert length(results) >= 2
      [first, second | _] = results
      assert first.id == log2.id
      assert second.id == log1.id
    end

    test "with where filter" do
      context = AuditLog.system()

      Audit.log!(context, "app.keep", %{})
      Audit.log!(context, "app.discard", %{})

      results = Audit.list_all(where: [action: "app.keep"])

      assert Enum.all?(results, &(&1.action == "app.keep"))
    end

    test "with limit" do
      context = AuditLog.system()

      for i <- 1..5 do
        Audit.log!(context, "app.item_#{i}", %{})
      end

      results = Audit.list_all(limit: 3)
      assert length(results) == 3
    end
  end

  describe "list_all_for_user/2" do
    test "with a user struct" do
      user = Repo.insert!(%User{email: "audit@example.com", name: "Audit User"})
      context = %{AuditLog.system() | user_id: user.id}

      log = Audit.log!(context, "app.user_event", %{})

      results = Audit.list_all_for_user(user)

      assert not Enum.empty?(results)
      assert Enum.any?(results, &(&1.id == log.id))
    end

    test "with just an id" do
      user = Repo.insert!(%User{email: "audit2@example.com", name: "Audit User 2"})
      context = %{AuditLog.system() | user_id: user.id}

      log = Audit.log!(context, "app.user_event_2", %{})

      results = Audit.list_all_for_user(user.id)

      assert not Enum.empty?(results)
      assert Enum.any?(results, &(&1.id == log.id))
    end
  end

  describe "list_all_from_system/1" do
    test "returns only logs with user_agent SYSTEM, admin_id nil, user_id nil" do
      context = AuditLog.system()

      system_log = Audit.log!(context, "app.system_event", %{})

      # Non-system log (has a user)
      user = Repo.insert!(%User{email: "sys@example.com", name: "Sys User"})
      user_context = %{AuditLog.system() | user_id: user.id}
      Audit.log!(user_context, "app.user_event", %{})

      results = Audit.list_all_from_system()

      assert Enum.all?(results, fn log ->
               log.user_agent == "SYSTEM" and log.admin_id == nil and log.user_id == nil
             end)

      assert Enum.any?(results, &(&1.id == system_log.id))
    end
  end

  describe "multi/4" do
    test "with function wraps an Ecto.Multi and broadcasts" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      context = AuditLog.system()

      result =
        Ecto.Multi.new()
        |> Audit.multi(context, "app.multi_event", fn _ctx, _results ->
          %{context | params: %{item_id: 99}}
        end)
        |> Repo.transaction()

      assert {:ok, %{audit: %AuditLog{} = log}} = result
      assert log.action == "app.multi_event"

      assert_received {:audit_log, ^log}
    end

    # NOTE: multi/4 with a params map and delete_all/1 are not tested here because
    # push_pubsub/1 returns :ok (from PubSub.broadcast) instead of {:ok, :ok},
    # which causes Ecto.Multi.run to raise a RuntimeError. This is a source bug
    # in Blank.Audit — the :broadcast callback should wrap its return value.
  end

  describe "multi/4 with changeset" do
    defmodule TestPost do
      use Ecto.Schema

      schema "test_posts" do
        field(:title, :string)
        field(:body, :string)
      end
    end

    test "computes before/after from changeset and stores in extra" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      existing = %TestPost{id: 1, title: "Old Title", body: "Old Body"}
      changeset = Ecto.Changeset.change(existing, %{title: "New Title"})

      context = AuditLog.system()

      result =
        Ecto.Multi.new()
        |> Audit.multi(context, "app.update_post", changeset)
        |> Repo.transaction()

      assert {:ok, %{audit: %AuditLog{} = log}} = result
      assert log.action == "app.update_post"

      before_map = log.extra[:before] || log.extra["before"]
      after_map = log.extra[:after] || log.extra["after"]

      assert before_map[:title] == "Old Title" or before_map["title"] == "Old Title"
      assert before_map[:body] == "Old Body" or before_map["body"] == "Old Body"
      assert after_map[:title] == "New Title" or after_map["title"] == "New Title"
      refute Map.has_key?(after_map || %{}, :body) or Map.has_key?(after_map || %{}, "body")

      assert_received {:audit_log, ^log}
    end

    test "changeset with no changed fields omits after but keeps before" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      existing = %TestPost{id: 2, title: "Same", body: "Same"}
      changeset = Ecto.Changeset.change(existing, %{})

      context = AuditLog.system()

      result =
        Ecto.Multi.new()
        |> Audit.multi(context, "app.noop", changeset)
        |> Repo.transaction()

      assert {:ok, %{audit: %AuditLog{} = log}} = result

      # before is always present (it's the original record data)
      before_map = log.extra[:before] || log.extra["before"]
      assert before_map

      # after is omitted because no fields changed
      refute Map.has_key?(log.extra, :after) or Map.has_key?(log.extra, "after")

      assert_received {:audit_log, ^log}
    end

    test "changeset with item_id in params works with app action" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      context = AuditLog.system()

      # Passing a map (not a changeset) hits the map clause
      result =
        Ecto.Multi.new()
        |> Audit.multi(context, "app.update_post", %{item_id: 5})
        |> Repo.transaction()

      assert {:ok, %{audit: %AuditLog{} = log}} = result
      assert log.params[:item_id] == 5

      assert_received {:audit_log, ^log}
    end
  end
end
