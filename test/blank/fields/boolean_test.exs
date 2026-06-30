defmodule Blank.Fields.BooleanTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with true returns rendered HTML with check icon" do
      definition = %Field{key: :published, module: Blank.Fields.Boolean, label: "Published"}

      html =
        render_component(&Blank.Fields.Boolean.render/1, %{
          type: :display,
          field: definition,
          value: true
        })

      assert html =~ "hero-check-circle"
    end

    test "with false returns rendered HTML with x icon" do
      definition = %Field{key: :published, module: Blank.Fields.Boolean, label: "Published"}

      html =
        render_component(&Blank.Fields.Boolean.render/1, %{
          type: :display,
          field: definition,
          value: false
        })

      assert html =~ "hero-x-circle"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML with checkbox" do
      definition = %Field{key: :published, module: Blank.Fields.Boolean, label: "Published"}
      form = Phoenix.Component.to_form(%{"published" => true})

      html =
        render_component(&Blank.Fields.Boolean.render/1, %{
          type: :form,
          field: form[:published],
          definition: definition
        })

      assert html =~ "Published"
      assert html =~ "checkbox"
    end
  end
end
