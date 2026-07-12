defmodule Blank.Components.ExportComponentTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, user: user_fixture(), conn: log_in_user(conn)}
  end

  test "mounting the posts export page shows export options", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/posts/export")

    assert html =~ "Export"
    assert html =~ "CSV"
  end

  test "clicking CSV export button triggers export and shows download modal", %{conn: conn} do
    # Create a post so there's data to export
    TestApp.Repo.insert!(%TestApp.Blog.Post{title: "Test Post", body: "body"})

    {:ok, view, _html} = live(conn, "/admin/posts/export")

    html =
      view
      |> element("button", "Export CSV")
      |> render_click()

    assert html =~ "Your download is ready!"
    assert html =~ "Download"
  end

  test "download modal has download and cancel links", %{conn: conn} do
    # Create a post so there's data to export
    TestApp.Repo.insert!(%TestApp.Blog.Post{title: "Test Post", body: "body"})

    {:ok, view, _html} = live(conn, "/admin/posts/export")

    html =
      view
      |> element("button", "Export CSV")
      |> render_click()

    assert html =~ "Your download is ready!"
    assert html =~ "Download"
    assert html =~ "Cancel"
  end
end
