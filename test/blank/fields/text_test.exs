defmodule Blank.Fields.TextTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "returns rendered HTML with a string value" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}

      html =
        render_component(&Blank.Fields.Text.render/1, %{
          type: :display,
          field: definition,
          value: "Hello"
        })

      assert html =~ "Hello"
    end

    test "returns rendered HTML with nil value" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}

      html =
        render_component(&Blank.Fields.Text.render/1, %{
          type: :display,
          field: definition,
          value: nil
        })

      assert html =~ "<span>"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML with form field" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}
      form = Phoenix.Component.to_form(%{"title" => "Hello"})

      html =
        render_component(&Blank.Fields.Text.render/1, %{
          type: :form,
          field: form[:title],
          definition: definition
        })

      assert html =~ "Title"
    end
  end
end
