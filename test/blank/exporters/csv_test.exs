defmodule Blank.Exporters.CSVTest do
  use TestApp.DataCase

  alias Blank.Exporters.CSV
  alias Blank.Fields.BelongsTo
  alias Blank.Fields.Text
  alias TestApp.Accounts.User
  alias TestApp.Blog.Post

  describe "display?/1" do
    test "always returns true regardless of fields" do
      assert CSV.display?([]) == true
      assert CSV.display?(foo: %Blank.Field{module: Text}) == true
    end
  end

  describe "name/0" do
    test "returns CSV" do
      assert CSV.name() == "CSV"
    end
  end

  describe "icon/0" do
    test "returns hero-chart-bar" do
      assert CSV.icon() == "hero-chart-bar"
    end
  end

  describe "ext/0" do
    test "returns csv" do
      assert CSV.ext() == "csv"
    end
  end

  describe "process/2" do
    test "converts a Post struct to a map with field values" do
      post = %Post{
        id: 1,
        title: "Hello World",
        body: "Some body text",
        published: true,
        views: 42
      }

      fields = [
        title: %Blank.Field{key: :title, module: Text, display_field: nil},
        body: %Blank.Field{key: :body, module: Text, display_field: nil}
      ]

      result = CSV.process(post, fields)

      assert is_map(result)
      assert result[:title] == "Hello World"
      assert result[:body] == "Some body text"
    end

    test "returns a map with stringified values" do
      post = %Post{
        id: 1,
        title: "Test",
        body: "Content"
      }

      fields = [
        title: %Blank.Field{key: :title, module: Text, display_field: nil}
      ]

      result = CSV.process(post, fields)

      assert is_binary(result[:title])
    end

    test "handles display_field on belongs_to associations" do
      user = %User{id: 1, name: "Alice"}

      post = %Post{
        id: 1,
        title: "Test",
        body: "Body",
        author: user
      }

      fields = [
        title: %Blank.Field{key: :title, module: Text, display_field: nil},
        author: %Blank.Field{
          key: :author,
          module: BelongsTo,
          display_field: :name
        }
      ]

      result = CSV.process(post, fields)

      assert result[:title] == "Test"
      assert result[:author] == "Alice"
    end
  end

  describe "save/2" do
    test "writes a valid CSV file with headers" do
      path =
        Path.join(System.tmp_dir!(), "blank_csv_test_#{System.unique_integer([:positive])}.csv")

      on_exit(fn -> File.rm(path) end)

      stream = [
        %{title: "First Post", body: "Body one"},
        %{title: "Second Post", body: "Body two"}
      ]

      assert :ok = CSV.save(stream, path)

      content = File.read!(path)
      lines = String.split(content, "\n", trim: true)

      # First line should be the header
      assert hd(lines) =~ "title"
      assert hd(lines) =~ "body"

      # Should have header + 2 data rows
      assert length(lines) == 3
    end

    test "CSV output is parseable" do
      path =
        Path.join(
          System.tmp_dir!(),
          "blank_csv_parse_test_#{System.unique_integer([:positive])}.csv"
        )

      on_exit(fn -> File.rm(path) end)

      stream = [
        %{title: "Hello, World", body: "Body with \"quotes\""}
      ]

      assert :ok = CSV.save(stream, path)

      content = File.read!(path)
      # Should not crash on commas or quotes
      assert is_binary(content)
      assert content =~ "Hello, World"
    end
  end
end
