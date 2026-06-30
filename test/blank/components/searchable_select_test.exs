defmodule Blank.Components.SearchableSelectTest do
  use Blank.LiveViewCase

  test "mounting shows the searchable select component", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/test/searchable_select")

    assert html =~ "Test Select"
    assert html =~ "test-searchable-select"
  end

  test "typing in the search field shows matching options", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/test/searchable_select")

    # Target the input which has phx-change="change"
    html =
      view
      |> element("#test-searchable-select_search_input")
      |> render_change(%{"test" => %{"field_search_input" => "app"}})

    assert html =~ "Apple"
  end
end
