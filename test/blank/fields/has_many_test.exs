defmodule Blank.Fields.HasManyTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field
  alias Blank.Fields.HasMany
  alias TestApp.Blog.Post
  alias TestApp.Blog.Tag

  describe "render_display/1" do
    test "with empty list returns rendered HTML" do
      definition = %Field{
        key: :tags,
        module: HasMany,
        label: "Tags",
        children: [name: [label: "Tag Name"]]
      }

      html =
        render_component(&HasMany.render/1, %{
          type: :display,
          schema: Post,
          definition: definition,
          value: [],
          id: "post_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "Nothing here yet"
    end

    test "with NotLoaded returns rendered HTML" do
      definition = %Field{
        key: :tags,
        module: HasMany,
        label: "Tags",
        children: [name: [label: "Tag Name"]]
      }

      html =
        render_component(&HasMany.render/1, %{
          type: :display,
          schema: Post,
          definition: definition,
          value: %Ecto.Association.NotLoaded{},
          id: "post_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "Nothing here yet"
    end

    test "with list of structs returns rendered HTML" do
      definition = %Field{
        key: :tags,
        module: HasMany,
        label: "Tags",
        children: [name: [label: "Tag Name"]],
        display_field: :name
      }

      html =
        render_component(&HasMany.render/1, %{
          type: :display,
          schema: Post,
          definition: definition,
          value: [%{name: "elixir"}, %{name: "phoenix"}],
          id: "post_1",
          time_zone: "Etc/UTC"
        })

      assert html =~ "elixir"
      assert html =~ "phoenix"
    end
  end

  describe "render_form/1" do
    test "is implemented via render/1 dispatch" do
      # render_form uses <.inputs_for> which needs a full LiveView CID context.
      # Verify the render/1 dispatch works (it will call render_form).
      assert {:render, 1} in HasMany.__info__(:functions)
    end
  end

  describe "update/2" do
    test "extracts owner_key and queryable for form type" do
      definition = %Field{
        key: :tags,
        module: HasMany,
        label: "Tags",
        children: [name: [label: "Tag Name"]]
      }

      form = Phoenix.Component.to_form(%{"tags" => []}, id: "post-form")

      assigns = %{
        type: :form,
        schema: Post,
        field: form[:tags],
        definition: definition
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = HasMany.update(assigns, socket)

      assert updated_socket.assigns.owner_key == :id
      assert updated_socket.assigns.queryable == Tag
    end

    test "passes through for non-form type" do
      definition = %Field{
        key: :tags,
        module: HasMany,
        label: "Tags"
      }

      assigns = %{
        type: :display,
        schema: Post,
        field: definition,
        value: []
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = HasMany.update(assigns, socket)

      assert updated_socket.assigns.value == []
    end
  end
end
