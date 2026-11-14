defmodule Blank.FieldsTest do
  use TestApp.DataCase

  alias Blank.Fields
  alias Blank.Fields.BelongsTo
  alias Blank.Fields.HasMany
  alias Blank.Fields.List
  alias TestApp.Blog.Article
  alias TestApp.Blog.Post
  alias TestApp.Blog.Review

  describe "new!/2" do
    test "new!/2 builds a field struct" do
      field = Fields.new!(:name, label: "My Name")
      assert %Blank.Field{} = field
      assert field.key == :name
      assert field.label == "My Name"
      assert field.module == Blank.Fields.Text
    end

    test "new!/2 with explicit module" do
      field = Fields.new!(:active, module: Blank.Fields.Boolean)
      assert field.key == :active
      assert field.module == Blank.Fields.Boolean
    end

    test "new!/2 with children" do
      field = Fields.new!(:items, children: [name: [label: "Name"]])

      assert field.key == :items
      assert is_list(field.children)

      [{:name, child}] = field.children
      assert %Blank.Field{} = child
      assert child.key == :name
      assert child.label == "Name"
      assert child.module == Blank.Fields.Text
    end

    test "new!/2 generates label from key if not provided" do
      field = Fields.new!(:first_name, [])
      assert field.label == "First name"
    end
  end

  describe "put_field_module/3" do
    test "returns BelongsTo for belongs_to association" do
      {module, _opts} = Fields.put_field_module([], :author, Post)
      assert module == BelongsTo
    end

    test "returns BelongsTo for Review's post association" do
      {module, _opts} = Fields.put_field_module([], :post, Review)
      assert module == BelongsTo
    end

    test "returns HasMany for has_many association" do
      {module, _opts} = Fields.put_field_module([], :tags, Post)
      assert module == HasMany
    end

    test "returns HasMany for Review's comments association" do
      {module, _opts} = Fields.put_field_module([], :comments, Post)
      assert module == HasMany
    end

    test "returns List for array field" do
      {module, _opts} = Fields.put_field_module([], :tag_names, Article)
      assert module == List
    end

    test "returns Text for :string type field" do
      {module, _opts} = Fields.put_field_module([], :title, Post)
      assert module == Blank.Fields.Text
    end

    test "returns Boolean for :boolean type field" do
      {module, _opts} = Fields.put_field_module([], :published, Post)
      assert module == Blank.Fields.Boolean
    end

    test "returns module from field_def when already set" do
      {module, opts} = Fields.put_field_module([module: Blank.Fields.Boolean], :title, Post)
      assert module == Blank.Fields.Boolean
      assert opts[:module] == Blank.Fields.Boolean
    end
  end
end
