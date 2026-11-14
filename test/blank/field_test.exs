defmodule Blank.FieldTest do
  use ExUnit.Case, async: true

  describe "field_schema/0" do
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
  end

  describe "validate_field!/3" do
    test "validate_field!/3 raises on invalid options" do
      error =
        assert_raise Blank.Errors.InvalidConfigError, fn ->
          Blank.Field.validate_field!([], __MODULE__, invalid_key: :bad)
        end

      message = Exception.message(error)
      # These options come from `@derive Blank.Schema`, so the label must say so.
      assert message =~ "@derive"
      assert message =~ "Blank.Schema"
      assert message =~ "`#{inspect(__MODULE__)}`"
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
end
