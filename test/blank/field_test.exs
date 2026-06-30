defmodule Blank.FieldTest do
  use ExUnit.Case, async: true

  test "module_for_type/1 maps :boolean to Boolean" do
    assert Blank.Field.module_for_type(:boolean) == Blank.Fields.Boolean
  end

  test "module_for_type/1 maps :utc_datetime to DateTime" do
    assert Blank.Field.module_for_type(:utc_datetime) == Blank.Fields.DateTime
  end

  test "module_for_type/1 maps unknown to Text" do
    assert Blank.Field.module_for_type(:string) == Blank.Fields.Text
    assert Blank.Field.module_for_type(:integer) == Blank.Fields.Text
    assert Blank.Field.module_for_type(:foo) == Blank.Fields.Text
  end

  test "new!/2 builds a field struct" do
    field = Blank.Field.new!(:name, label: "My Name")
    assert %Blank.Field{} = field
    assert field.key == :name
    assert field.label == "My Name"
    assert field.module == Blank.Fields.Text
  end

  test "new!/2 with explicit module" do
    field = Blank.Field.new!(:active, module: Blank.Fields.Boolean)
    assert field.key == :active
    assert field.module == Blank.Fields.Boolean
  end

  test "new!/2 with children" do
    field = Blank.Field.new!(:items, children: [name: [label: "Name"]])

    assert field.key == :items
    assert is_list(field.children)

    [{:name, child}] = field.children
    assert %Blank.Field{} = child
    assert child.key == :name
    assert child.label == "Name"
    assert child.module == Blank.Fields.Text
  end

  test "new!/2 generates label from key if not provided" do
    field = Blank.Field.new!(:first_name, [])
    assert field.label == "First name"
  end

  test "field_schema/0 returns the field schema" do
    schema = Blank.Field.field_schema()
    assert is_list(schema)
    assert Keyword.has_key?(schema, :module)
    assert Keyword.has_key?(schema, :label)
    assert Keyword.has_key?(schema, :placeholder)
    assert Keyword.has_key?(schema, :searchable)
    assert Keyword.has_key?(schema, :sortable)
    assert Keyword.has_key?(schema, :readonly)
    assert Keyword.has_key?(schema, :viewable)
    assert Keyword.has_key?(schema, :display_field)
    assert Keyword.has_key?(schema, :select)
    assert Keyword.has_key?(schema, :filter_key)
  end

  test "validate_field!/3 raises on invalid options" do
    assert_raise Blank.Errors.InvalidConfigError, fn ->
      Blank.Field.validate_field!([], __MODULE__, invalid_key: :bad)
    end
  end

  test "validate_field!/3 with valid options returns the opts" do
    opts = Blank.Field.validate_field!([], __MODULE__, label: "Test", readonly: true)
    assert Keyword.get(opts, :label) == "Test"
    assert Keyword.get(opts, :readonly) == true
  end

  test "validate_field!/3 merges field schema with custom schema" do
    # Blank.Fields.Text has an empty schema, so only base field_schema applies
    opts = Blank.Field.validate_field!([], __MODULE__, searchable: true)
    assert Keyword.get(opts, :searchable) == true
  end
end
