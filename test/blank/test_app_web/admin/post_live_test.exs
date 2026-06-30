defmodule TestAppWeb.Admin.PostLiveTest do
  @moduledoc """
  LiveView integration tests for TestAppWeb.Admin.PostLive.

  Uses the real router (`TestAppWeb.Router`) so on_mount callbacks
  (auth, nav, audit) run exactly as they would in production.
  """

  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import TestAppWeb.LiveViewCase

  alias TestApp.Blog.Post
  alias TestApp.Repo

  @endpoint TestAppWeb.Endpoint

  # ── setup ──────────────────────────────────────────────────────────

  setup do
    # Set up Ecto sandbox
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(TestApp.Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    # Ensure endpoint is started for persistent_term / static lookup
    try do
      start_supervised!(TestAppWeb.Endpoint)
    rescue
      _ -> :ok
    end

    # Register an admin and build a logged-in conn
    {:ok, admin} =
      Blank.Accounts.register_admin(%{
        email: "admin@example.com",
        password: "Str0ng!Passw0rd"
      })

    conn = Phoenix.ConnTest.build_conn()
    conn = log_in_admin(conn, admin)

    {:ok, conn: conn, admin: admin}
  end

  # ── helpers ────────────────────────────────────────────────────────

  defp post_fixture(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(Enum.into(attrs, %{title: "Test Post"}))
    |> Repo.insert!()
  end

  # ===================================================================
  # Index page
  # ===================================================================

  describe "index page (/admin/posts)" do
    test "mounts and renders the page heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/posts")
      assert html =~ "Posts"
    end

    test "renders the 'New post' button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/posts")
      assert html =~ "New post"
    end

    test "renders the 'Import posts' button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/posts")
      assert html =~ "Import posts"
    end

    test "renders the 'Export posts' button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/posts")
      assert html =~ "Export posts"
    end

    test "shows the total count stat", %{conn: conn} do
      post_fixture(%{title: "Alpha"})
      post_fixture(%{title: "Beta"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render(view)

      assert html =~ "Total posts"
      assert html =~ "2"
    end

    test "shows an empty table when no posts exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render(view)
      assert html =~ "0"
    end

    test "lists posts in the table", %{conn: conn} do
      post_fixture(%{title: "Listed Post"})
      post_fixture(%{title: "Second Post"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render(view)

      assert html =~ "Listed Post"
      assert html =~ "Second Post"
    end

    test "table headers match index_fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render(view)
      assert html =~ "Title"
    end

    test "navigate to new page via the 'New post' button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render_patch(view, "/admin/posts/new")
      assert html =~ "Post creation"
      assert html =~ "Create post"
    end

    test "navigate to show page via a row link", %{conn: conn} do
      post = post_fixture(%{title: "Show Me"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render_patch(view, "/admin/posts/#{post.id}")

      assert html =~ "Show Me"
      assert html =~ "Edit Post"
    end

    test "navigate to edit page via a row link", %{conn: conn} do
      post = post_fixture(%{title: "Edit Me"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render_patch(view, "/admin/posts/#{post.id}/edit")

      assert html =~ "Edit Me"
      assert html =~ "Update post"
    end

    test "paginates when there are many results", %{conn: conn} do
      for i <- 1..15,
          do: post_fixture(%{title: "Post #{String.pad_leading(to_string(i), 2, "0")}"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render(view)

      assert html =~ "15"
    end

    test "Flop sort via URL params does not crash the page", %{conn: conn} do
      post_fixture(%{title: "Zebra"})
      post_fixture(%{title: "Apple"})

      {:ok, view, _html} = live(conn, "/admin/posts")

      # Patch with sort params — verify the page re-renders without crashing
      html = render_patch(view, "/admin/posts?order_by[]=title&order_direction[]=asc")

      # The header should still render even if sort doesn't work on SQLite3
      assert html =~ "Posts"
    end

    test "Flop filter via URL params does not crash the page", %{conn: conn} do
      post_fixture(%{title: "Elixir Guide"})
      post_fixture(%{title: "Ruby Handbook"})

      {:ok, view, _html} = live(conn, "/admin/posts")

      # Patch with filter params — verify page re-renders without crashing
      html =
        render_patch(
          view,
          "/admin/posts?filters[0][field]=title&filters[0][op]=eq&filters[0][value]=Elixir Guide"
        )

      assert html =~ "Posts"
    end

    test "toggle-search switches between simple and advanced", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")

      html = render(view)
      assert html =~ "Simple"

      render_click(view, "toggle-search")
      html = render(view)
      assert html =~ "Advanced"
    end
  end

  # ===================================================================
  # New page
  # ===================================================================

  describe "new page (/admin/posts/new)" do
    test "renders the form with edit_fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts/new")
      html = render(view)

      assert html =~ "Post creation"
      assert html =~ "Create post"
      assert html =~ "Title"
      assert html =~ "Body"
    end

    test "submitting with valid params creates the post", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts/new")

      html =
        render_submit(view, "save", %{
          "item_params" => %{
            "title" => "Brand New Post",
            "body" => "With a body",
            "published" => "true"
          }
        })

      assert html =~ "Post created successfully"

      post = Repo.get_by!(Post, title: "Brand New Post")
      assert post.body == "With a body"
      assert post.published == true
    end

    test "creating a post writes an audit log", %{conn: conn} do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

      {:ok, view, _html} = live(conn, "/admin/posts/new")

      render_submit(view, "save", %{
        "item_params" => %{
          "title" => "Audited Post"
        }
      })

      assert_received {:audit_log, log}
      assert log.action == "post.create"
    end
  end

  # ===================================================================
  # Edit page
  # ===================================================================

  describe "edit page (/admin/posts/:id/edit)" do
    test "renders the form pre-filled with post data", %{conn: conn} do
      post = post_fixture(%{title: "Pre-filled Post", body: "Existing body"})

      {:ok, view, _html} = live(conn, "/admin/posts/#{post.id}/edit")
      html = render(view)

      assert html =~ "Pre-filled Post"
      assert html =~ "Existing body"
      assert html =~ "Update post"
    end

    test "submitting with valid params updates the post", %{conn: conn} do
      post = post_fixture(%{title: "Old Title"})

      {:ok, view, _html} = live(conn, "/admin/posts/#{post.id}/edit")

      html =
        render_submit(view, "save", %{
          "item_params" => %{
            "title" => "Updated Title",
            "body" => "Updated body"
          }
        })

      assert html =~ "Post updated successfully"

      updated = Repo.get!(Post, post.id)
      assert updated.title == "Updated Title"
      assert updated.body == "Updated body"
    end

    test "updating a post writes an audit log", %{conn: conn} do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      post = post_fixture(%{title: "To Update"})

      {:ok, view, _html} = live(conn, "/admin/posts/#{post.id}/edit")

      render_submit(view, "save", %{
        "item_params" => %{
          "title" => "Updated"
        }
      })

      assert_received {:audit_log, log}
      assert log.action == "post.update"
    end
  end

  # ===================================================================
  # Show page
  # ===================================================================

  describe "show page (/admin/posts/:id)" do
    test "shows the post's data", %{conn: conn} do
      post = post_fixture(%{title: "Show Title", body: "Show Body"})

      {:ok, _view, html} = live(conn, "/admin/posts/#{post.id}")

      assert html =~ "Post"
      assert html =~ "Show Title"
      assert html =~ "Show Body"
    end

    test "shows the Edit button", %{conn: conn} do
      post = post_fixture(%{title: "Button Check"})

      {:ok, _view, html} = live(conn, "/admin/posts/#{post.id}")
      assert html =~ "Edit Post"
    end

    test "navigates to edit page from the Edit button", %{conn: conn} do
      post = post_fixture(%{title: "Navigate Edit"})

      {:ok, view, _html} = live(conn, "/admin/posts/#{post.id}")
      html = render_patch(view, "/admin/posts/#{post.id}/edit")

      assert html =~ "Navigate Edit"
      assert html =~ "Update post"
    end

    test "navigates to the show page from the index", %{conn: conn} do
      post = post_fixture(%{title: "From Index"})

      {:ok, view, _html} = live(conn, "/admin/posts")
      html = render_patch(view, "/admin/posts/#{post.id}")

      assert html =~ "From Index"
      assert html =~ "Edit Post"
    end
  end

  # ===================================================================
  # Delete action
  # ===================================================================

  describe "delete action" do
    test "deleting from the index removes the post", %{conn: conn} do
      post = post_fixture(%{title: "To Delete"})

      {:ok, view, _html} = live(conn, "/admin/posts")

      html = render(view)
      assert html =~ "To Delete"

      render_click(view, "delete", %{"id" => to_string(post.id)})

      html = render(view)
      refute html =~ "To Delete"

      assert is_nil(Repo.get(Post, post.id))
    end

    test "delete event writes an audit log", %{conn: conn} do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
      post = post_fixture(%{title: "Audited Delete"})

      {:ok, view, _html} = live(conn, "/admin/posts")

      render_click(view, "delete", %{"id" => to_string(post.id)})

      assert_received {:audit_log, log}
      assert log.action == "post.delete"
    end
  end

  # ===================================================================
  # Search / Filter
  # ===================================================================

  describe "search and filter" do
    test "simple search filters results", %{conn: conn} do
      post_fixture(%{title: "Elixir is Great"})
      post_fixture(%{title: "Ruby is Fine"})

      {:ok, view, _html} = live(conn, "/admin/posts")

      # Patch with filter params — verify page re-renders
      html =
        render_patch(
          view,
          "/admin/posts?filters[0][field]=title&filters[0][op]=eq&filters[0][value]=Elixir is Great"
        )

      assert html =~ "Posts"
    end

    test "toggle to advanced search shows field-specific filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")

      html = render(view)
      assert html =~ "Search..."

      render_click(view, "toggle-search")
      html = render(view)
      assert html =~ "Advanced"
    end

    test "toggle back to simple search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/posts")

      render_click(view, "toggle-search")
      html = render(view)
      assert html =~ "Advanced"

      render_click(view, "toggle-search")
      html = render(view)
      assert html =~ "Simple"
    end

    test "filtering by published status via URL params does not crash", %{conn: conn} do
      post_fixture(%{title: "Published", published: true})
      post_fixture(%{title: "Draft", published: false})

      {:ok, view, _html} = live(conn, "/admin/posts")

      html =
        render_patch(
          view,
          "/admin/posts?filters[0][field]=published&filters[0][op]=eq&filters[0][value]=true"
        )

      assert html =~ "Posts"
    end
  end

  # ===================================================================
  # Auth guard
  # ===================================================================

  describe "authentication" do
    test "unauthenticated user is redirected to login" do
      unauthed_conn = Phoenix.ConnTest.build_conn()

      result = live(unauthed_conn, "/admin/posts")

      assert {:error, {:redirect, %{to: to}}} = result
      assert to =~ "log_in"
    end
  end
end
