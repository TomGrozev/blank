defmodule Blank.Components.FieldTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  # Minimal wrapper modules for testing field_list, field_display, field_form
  # These render live_components, so we need a Phoenix.Component context

  defmodule FieldListWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.Field.field_list
        definition={@definition}
        value={@value}
        id={@id}
        schema={@schema}
        time_zone={@time_zone}
        path_prefix={@path_prefix}
      />
      """
    end
  end

  defmodule FieldDisplayWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.Field.field_display
        definition={@definition}
        value={@value}
        id={@id}
        schema={@schema}
        time_zone={@time_zone}
        path_prefix={@path_prefix}
      />
      """
    end
  end

  defmodule FieldFormWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.Field.field_form
        definition={@definition}
        field={@field}
        schema={@schema}
        repo={@repo}
        time_zone={@time_zone}
        path_prefix={@path_prefix}
      />
      """
    end
  end

  describe "field_list/1" do
    test "renders a live_component with the field definition" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}

      # field_list renders a .live_component, so we need to test via render_component
      # which handles live_component rendering in a test context
      html =
        render_component(&FieldListWrapper.render/1, %{
          definition: definition,
          value: "Hello",
          id: "test-1",
          schema: nil,
          time_zone: nil,
          path_prefix: nil
        })

      # The live_component should render the Text field's display view
      assert html =~ "Hello"
    end

    test "renders with boolean field" do
      definition = %Field{key: :active, module: Blank.Fields.Boolean, label: "Active"}

      html =
        render_component(&FieldListWrapper.render/1, %{
          definition: definition,
          value: true,
          id: "test-2",
          schema: nil,
          time_zone: nil,
          path_prefix: nil
        })

      # Boolean field shows a check icon for true
      assert html =~ "hero-check-circle"
    end
  end

  describe "field_display/1" do
    test "renders a live_component with the field definition" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}

      html =
        render_component(&FieldDisplayWrapper.render/1, %{
          definition: definition,
          value: "World",
          id: "test-3",
          schema: nil,
          time_zone: nil,
          path_prefix: nil
        })

      assert html =~ "World"
    end

    test "renders nil value" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}

      html =
        render_component(&FieldDisplayWrapper.render/1, %{
          definition: definition,
          value: nil,
          id: "test-4",
          schema: nil,
          time_zone: nil,
          path_prefix: nil
        })

      # Text field renders a span even with nil
      assert html =~ "<span>"
    end
  end

  describe "field_form/1" do
    test "renders a form field" do
      definition = %Field{key: :title, module: Blank.Fields.Text, label: "Title"}
      form = Phoenix.Component.to_form(%{"title" => "Hello"})
      field = form[:title]

      html =
        render_component(&FieldFormWrapper.render/1, %{
          definition: definition,
          field: field,
          schema: nil,
          repo: nil,
          time_zone: nil,
          path_prefix: nil
        })

      # Should render the form input with label
      assert html =~ "Title"
    end

    test "renders a boolean checkbox field" do
      definition = %Field{key: :active, module: Blank.Fields.Boolean, label: "Active"}
      form = Phoenix.Component.to_form(%{"active" => true})
      field = form[:active]

      html =
        render_component(&FieldFormWrapper.render/1, %{
          definition: definition,
          field: field,
          schema: nil,
          repo: nil,
          time_zone: nil,
          path_prefix: nil
        })

      assert html =~ "Active"
      assert html =~ "checkbox"
    end
  end

  describe "field definition struct" do
    test "creates a field with default module" do
      field = Field.new!(:name, [])
      assert field.key == :name
      assert field.module == Blank.Fields.Text
      assert field.label == "Name"
    end

    test "creates a field with custom module" do
      field = Field.new!(:active, module: Blank.Fields.Boolean)
      assert field.key == :active
      assert field.module == Blank.Fields.Boolean
    end

    test "creates a field with label override" do
      field = Field.new!(:name, label: "Full Name")
      assert field.label == "Full Name"
    end

    test "field has correct default values" do
      field = Field.new!(:title, [])
      assert field.viewable == true
      assert field.searchable == false
      assert field.sortable == false
      assert field.readonly == false
      assert field.display_field == nil
      assert field.select == nil
    end
  end
end
