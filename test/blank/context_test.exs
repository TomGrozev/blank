defmodule Blank.ContextTest do
  use TestApp.DataCase

  alias Blank.Audit.AuditLog
  alias Blank.Context

  describe "list_query/2" do
    test "builds an Ecto.Query struct" do
      query = Context.list_query(Post, [])
      assert %Ecto.Query{} = query
    end
  end

  describe "list_schema/3" do
    test "returns all records" do
      post1 = Repo.insert!(%Post{title: "Post A"})
      post2 = Repo.insert!(%Post{title: "Post B"})

      results = Context.list_schema(TestApp.Repo, Post, [])

      assert length(results) == 2
      ids = Enum.map(results, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([post1.id, post2.id])
    end
  end

  describe "list_schema_by_ids/3" do
    test "returns only records with matching primary keys" do
      post1 = Repo.insert!(%Post{title: "Keep"})
      _post2 = Repo.insert!(%Post{title: "Skip"})
      post3 = Repo.insert!(%Post{title: "Also Keep"})

      results = Context.list_schema_by_ids(TestApp.Repo, Post, [post1.id, post3.id])

      assert length(results) == 2
      ids = Enum.map(results, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([post1.id, post3.id])
    end
  end

  describe "paginate_schema/4" do
    test "returns paginated results with Flop meta" do
      for i <- 1..5 do
        Repo.insert!(%Post{title: "Post #{i}"})
      end

      {:ok, {posts, meta}} = Context.paginate_schema(TestApp.Repo, Post, %{}, [])

      assert not Enum.empty?(posts)
      assert %Flop.Meta{} = meta
    end
  end

  # NOTE: options_query/4 is not tested here because it uses Ecto.Query.ilike/2
  # which is not supported by the SQLite3 adapter used in the test environment.

  describe "get!/3" do
    test "returns a single record by id" do
      post = Repo.insert!(%Post{title: "Fetch Me"})

      fetched = Context.get!(TestApp.Repo, Post, post.id)
      assert fetched.id == post.id
      assert fetched.title == "Fetch Me"
    end
  end

  describe "get!/4" do
    test "returns a single record with fields query" do
      post = Repo.insert!(%Post{title: "With Fields"})

      fetched = Context.get!(TestApp.Repo, Post, post.id, [])
      assert fetched.id == post.id
    end
  end

  describe "change/3" do
    test "builds a changeset for :new action" do
      changeset = Context.change(%Post{}, :new, %{title: "New Post"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :title) == "New Post"
    end

    test "builds a changeset for :edit action" do
      post = Repo.insert!(%Post{title: "Existing"})
      changeset = Context.change(post, :edit, %{title: "Updated"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :title) == "Updated"
    end
  end

  describe "create/4" do
    test "inserts a new record and writes an audit log" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      context = AuditLog.system()

      {:ok, post} = Context.create(TestApp.Repo, context, %Post{}, %{title: "Created Post"})

      assert post.id
      assert post.title == "Created Post"

      assert_received {:audit_log, %AuditLog{action: "post.create"}}
    end
  end

  describe "update/4" do
    test "updates a record and writes an audit log" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      context = AuditLog.system()

      post = Repo.insert!(%Post{title: "Old Title"})
      {:ok, updated} = Context.update(TestApp.Repo, context, post, %{title: "New Title"})

      assert updated.title == "New Title"

      assert_received {:audit_log, %AuditLog{action: "post.update"}}
    end
  end

  describe "delete/3" do
    test "deletes a record and writes an audit log" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      context = AuditLog.system()

      post = Repo.insert!(%Post{title: "To Delete"})
      {:ok, deleted} = Context.delete(TestApp.Repo, context, post)

      assert deleted.id == post.id
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Post, post.id) end

      assert_received {:audit_log, %AuditLog{action: "post.delete"}}
    end
  end

  describe "create_multiple/4" do
    test "inserts many records and writes a single audit log" do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      context = AuditLog.system()

      params = [
        %{title: "Multi 1"},
        %{title: "Multi 2"},
        %{title: "Multi 3"}
      ]

      {:ok, count} = Context.create_multiple(TestApp.Repo, context, Post, params)

      assert count == 3

      posts = Repo.all(Post)
      assert length(posts) == 3
      titles = Enum.map(posts, & &1.title) |> Enum.sort()
      assert titles == ["Multi 1", "Multi 2", "Multi 3"]

      assert_received {:audit_log, %AuditLog{action: "post.create_multiple"}}
    end
  end
end
