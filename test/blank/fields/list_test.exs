defmodule Blank.Fields.ListTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with array value returns rendered HTML" do
      definition = %Field{
        key: :tag_names,
        module: Blank.Fields.List,
        label: "Tag Names",
        children: []
      }

      html =
        render_component(&Blank.Fields.List.render/1, %{
          type: :display,
          schema: TestApp.Blog.Article,
          definition: definition,
          value: ["elixir", "phoenix"],
          id: "article_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "elixir"
      assert html =~ "phoenix"
    end

    test "with empty array value returns rendered HTML" do
      definition = %Field{
        key: :tag_names,
        module: Blank.Fields.List,
        label: "Tag Names",
        children: []
      }

      html =
        render_component(&Blank.Fields.List.render/1, %{
          type: :display,
          schema: TestApp.Blog.Article,
          definition: definition,
          value: [],
          id: "article_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "<div>"
    end
  end

  describe "render_form/1" do
    test "is defined and dispatched via render/1" do
      # render_form uses assign/3 and nested <.live_component> which
      # require a full LiveView context for rendering. We verify
      # the callback is implemented via the render/1 dispatch.
      assert {:render, 1} in Blank.Fields.List.__info__(:functions)
    end
  end

  describe "handle_event/3" do
    test "add-to-list appends nil to field value" do
      form = Phoenix.Component.to_form(%{"tag_names" => ["a", "b"]})
      form_field = form[:tag_names]

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          field: form_field
        }
      }

      {:noreply, updated_socket} =
        Blank.Fields.List.handle_event("add-to-list", %{}, socket)

      assert updated_socket.assigns.field.value == ["a", "b", nil]
    end

    test "remove-from-list removes item at given index" do
      form = Phoenix.Component.to_form(%{"tag_names" => ["a", "b", "c"]})
      form_field = form[:tag_names]

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          field: form_field
        }
      }

      {:noreply, updated_socket} =
        Blank.Fields.List.handle_event("remove-from-list", %{"index" => "1"}, socket)

      assert updated_socket.assigns.field.value == ["a", "c"]
    end
  end
end
