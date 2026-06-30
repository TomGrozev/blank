defmodule Blank.Fields.BelongsToTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with NotLoaded returns rendered HTML" do
      definition = %Field{
        key: :author,
        module: Blank.Fields.BelongsTo,
        label: "Author",
        display_field: :name
      }

      html =
        render_component(&Blank.Fields.BelongsTo.render/1, %{
          type: :display,
          schema: TestApp.Blog.Post,
          definition: definition,
          value: %Ecto.Association.NotLoaded{},
          id: "post_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "nil"
    end

    test "with value and display_field returns rendered HTML" do
      definition = %Field{
        key: :author,
        module: Blank.Fields.BelongsTo,
        label: "Author",
        display_field: :name
      }

      html =
        render_component(&Blank.Fields.BelongsTo.render/1, %{
          type: :display,
          schema: TestApp.Blog.Post,
          definition: definition,
          value: %{name: "Alice"},
          id: "post_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "Alice"
    end
  end

  describe "update/2" do
    test "extracts owner_key and queryable for form type" do
      definition = %Field{
        key: :author,
        module: Blank.Fields.BelongsTo,
        label: "Author",
        display_field: :name
      }

      # The form field's .field atom must match the association name (:author)
      form = Phoenix.Component.to_form(%{"author" => nil}, as: "post", id: "post-form")

      assigns = %{
        type: :form,
        schema: TestApp.Blog.Post,
        field: form[:author],
        definition: definition
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = Blank.Fields.BelongsTo.update(assigns, socket)

      assert updated_socket.assigns.owner_key == :author_id
      assert updated_socket.assigns.queryable == TestApp.Accounts.User
    end

    test "passes through for non-form type" do
      definition = %Field{
        key: :author,
        module: Blank.Fields.BelongsTo,
        label: "Author",
        display_field: :name
      }

      assigns = %{
        type: :display,
        schema: TestApp.Blog.Post,
        field: definition,
        value: %{name: "Alice"}
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = Blank.Fields.BelongsTo.update(assigns, socket)

      assert updated_socket.assigns.value == %{name: "Alice"}
    end
  end
end
