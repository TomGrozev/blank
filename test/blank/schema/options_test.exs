defmodule Blank.Schema.OptionsTest do
  use ExUnit.Case, async: true

  alias Blank.Errors.InvalidConfigError
  alias Blank.Schema.Options

  test "__schema__/0 returns NimbleOptions schema" do
    schema = Options.__schema__()
    assert is_list(schema)
    assert Keyword.has_key?(schema, :identity_field)
    assert Keyword.has_key?(schema, :create_changeset)
    assert Keyword.has_key?(schema, :update_changeset)
    assert Keyword.has_key?(schema, :fields)
    assert Keyword.has_key?(schema, :order_field)
    assert Keyword.has_key?(schema, :flop_opts)
    assert Keyword.has_key?(schema, :include_foreign_keys)
  end

  test "validate!/2 with valid options" do
    opts = [
      identity_field: :email,
      create_changeset: &__MODULE__.changeset/2,
      update_changeset: &__MODULE__.changeset/2,
      order_field: :inserted_at,
      include_foreign_keys: false
    ]

    # Should not raise
    result = Options.validate!(opts, __MODULE__)
    assert is_list(result)
    assert Keyword.get(result, :identity_field) == :email
  end

  test "validate!/2 with unknown key raises InvalidConfigError" do
    assert_raise InvalidConfigError, fn ->
      Options.validate!([unknown_key: :bad], __MODULE__)
    end
  end

  test "validate!/2 rejects non-atom identity_field" do
    assert_raise InvalidConfigError, fn ->
      Options.validate!([identity_field: "string"], __MODULE__)
    end
  end

  # Helper function for the changeset option
  def changeset(_schema, _changes), do: nil
end
