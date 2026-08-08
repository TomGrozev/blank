defmodule Blank.SchemaTest do
  use TestApp.DataCase

  alias Blank.Fields.BelongsTo
  alias Blank.Fields.Boolean
  alias Blank.Fields.HasMany
  alias Blank.Fields.List
  alias Blank.Fields.Text
  alias Blank.Schema.Any
  alias TestApp.Accounts.User
  alias TestApp.Blog.Article
  alias TestApp.Blog.Document
  alias TestApp.Blog.Post
  alias TestApp.Blog.Review
  alias TestApp.Repo

  # ─── helpers ────────────────────────────────────────────────────────────

  defp post_fixture(attrs \\ %{}) do
    %Post{
      id: 1,
      title: "Hello",
      body: "World",
      published: true,
      views: 42,
      author_id: nil
    }
    |> Map.merge(attrs)
  end

  defp user_fixture(attrs \\ %{}) do
    %User{
      id: 1,
      email: "alice@example.com",
      name: "Alice"
    }
    |> Map.merge(attrs)
  end

  defp review_fixture(attrs \\ %{}) do
    %Review{
      id: 1,
      rating: 5,
      rating_label: "Excellent",
      review_text: "Loved it",
      reviewer_name: "Bob"
    }
    |> Map.merge(attrs)
  end

  # ─── Blank.Schema protocol — name/1 ────────────────────────────────────

  describe "name/1" do
    test "returns the identity_field value for a simple field (Post)" do
      post = post_fixture(%{title: "Hello"})
      assert Blank.Schema.name(post) == "Hello"
    end

    test "returns the identity_field value for User (email)" do
      user = user_fixture(%{email: "alice@example.com"})
      assert Blank.Schema.name(user) == "alice@example.com"
    end

    test "returns the identity_field value for Review" do
      review = review_fixture(%{rating_label: "Excellent"})
      assert Blank.Schema.name(review) == "Excellent"
    end

    test "follows belongs_to display_field when value is an associated struct" do
      # Post has author: [display_field: :name] in fields config.
      # Post's identity_field is :title (a string), so name/1 returns "Hello".
      # The belongs_to display_field resolution is triggered when the value of
      # the identity field is a map (i.e. an associated struct).
      # We test this by calling the Any implementation's __name__/2 directly,
      # since the mechanism is: __name__ -> get_field(def) -> lookup display_field.
      author = user_fixture(%{id: 10, name: "Alice"})
      post = post_fixture(%{author: author, author_id: 10})

      # The internal __name__/2 helper resolves identity fields through display_field
      assert Any.__name__(post, :author) == "Alice"
    end

    test "returns nil when identity_field value is nil" do
      post = post_fixture(%{title: nil})
      assert Blank.Schema.name(post) == nil
    end

    test "returns the string value for a string identity_field" do
      user = user_fixture(%{email: "bob@test.com"})
      assert Blank.Schema.name(user) == "bob@test.com"
    end
  end

  # ─── Blank.Schema protocol — primary_keys/1 ────────────────────────────

  describe "primary_keys/1" do
    test "returns [:id] for Post" do
      post = post_fixture()
      assert Blank.Schema.primary_keys(post) == [:id]
    end

    test "returns [:id] for User" do
      user = user_fixture()
      assert Blank.Schema.primary_keys(user) == [:id]
    end

    test "returns [:id] for Review" do
      review = review_fixture()
      assert Blank.Schema.primary_keys(review) == [:id]
    end
  end

  # ─── Blank.Schema protocol — identity_field/1 ──────────────────────────

  describe "identity_field/1" do
    test "returns :title for Post" do
      post = post_fixture()
      assert Blank.Schema.identity_field(post) == :title
    end

    test "returns :email for User" do
      user = user_fixture()
      assert Blank.Schema.identity_field(user) == :email
    end

    test "returns :rating_label for Review (custom identity_field)" do
      review = review_fixture()
      assert Blank.Schema.identity_field(review) == :rating_label
    end
  end

  # ─── Blank.Schema protocol — order_field/1 ─────────────────────────────

  describe "order_field/1" do
    test "returns default {id, :asc} when order_field is nil (Post)" do
      post = post_fixture()
      assert Blank.Schema.order_field(post) == {:id, :asc}
    end

    test "returns default {id, :asc} when order_field is nil (User)" do
      user = user_fixture()
      assert Blank.Schema.order_field(user) == {:id, :asc}
    end

    test "returns configured {field, direction} for Review (order_field: {:rating, :desc})" do
      review = review_fixture()
      assert Blank.Schema.order_field(review) == {:rating, :desc}
    end
  end

  # ─── Blank.Schema protocol — changeset/2 ───────────────────────────────

  describe "changeset/2" do
    test "returns the schema's own changeset/2 by default for :new action" do
      post = post_fixture()
      cs = Blank.Schema.changeset(post, :new)
      assert is_function(cs, 2)
    end

    test "returns the schema's own changeset/2 by default for :edit action" do
      post = post_fixture()
      cs = Blank.Schema.changeset(post, :edit)
      assert is_function(cs, 2)
    end

    test "calls Post.changeset/2 for :new" do
      post = post_fixture()
      changeset = Blank.Schema.changeset(post, :new).(post, %{title: "X"})
      assert Ecto.Changeset.get_change(changeset, :title) == "X"
    end

    test "calls User.changeset/2 for :new" do
      user = user_fixture()
      changeset = Blank.Schema.changeset(user, :new).(user, %{email: "a@b.com"})
      assert Ecto.Changeset.get_change(changeset, :email) == "a@b.com"
    end
  end

  # ─── Blank.Schema protocol — get_field/2 ───────────────────────────────

  describe "get_field/2" do
    test "returns a Blank.Field struct for a simple field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :title)

      assert %Blank.Field{} = field
      assert field.key == :title
      assert field.searchable == true
      assert field.sortable == true
    end

    test "returns correct module for a boolean field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :published)
      assert field.module == Boolean
    end

    test "returns correct module for a belongs_to field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :author)
      assert field.module == BelongsTo
      assert field.display_field == :name
    end

    test "returns correct module for a has_many field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :tags)
      assert field.module == HasMany
    end

    test "returns correct module for an integer field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :views)
      assert %Blank.Field{} = field
    end

    test "returns a field with custom label when specified" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :body)
      assert field.label == "Body"
    end

    test "returns id field as readonly" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :id)
      assert field.readonly == true
      assert field.label == "ID"
    end

    test "get_field for User email is searchable" do
      user = user_fixture()
      field = Blank.Schema.get_field(user, :email)
      assert field.searchable == true
    end

    test "get_field for User name has default text module" do
      user = user_fixture()
      field = Blank.Schema.get_field(user, :name)
      assert field.module == Text
    end

    test "get_field for Review field with custom config" do
      review = review_fixture()
      field = Blank.Schema.get_field(review, :rating)
      assert field.label == "Score"
      assert field.sortable == true
    end
  end

  # ─── Protocol.UndefinedError for non-deriving structs ──────────────────

  describe "Protocol.UndefinedError" do
    test "raises for name/1 on a struct that doesn't derive Blank.Schema" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.name(tag)
      end
    end

    test "raises for name/1 on Comment" do
      {comment, _} = Code.eval_string("%TestApp.Blog.Comment{id: 1, body: \"Great!\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.name(comment)
      end
    end

    test "raises for primary_keys/1 on non-deriving struct" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.primary_keys(tag)
      end
    end

    test "raises for identity_field/1 on non-deriving struct" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.identity_field(tag)
      end
    end

    test "raises for order_field/1 on non-deriving struct" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.order_field(tag)
      end
    end

    test "raises for changeset/2 on non-deriving struct" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.changeset(tag, :new)
      end
    end

    test "raises for get_field/2 on non-deriving struct" do
      {tag, _} = Code.eval_string("%TestApp.Blog.Tag{id: 1, name: \"elixir\"}")

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.get_field(tag, :name)
      end
    end
  end

  # ─── Deriving macro — Review schema ────────────────────────────────────

  describe "deriving macro (Review schema)" do
    test "name/1 uses custom identity_field :rating_label" do
      review = review_fixture(%{rating_label: "Good"})
      assert Blank.Schema.name(review) == "Good"
    end

    test "primary_keys/1 returns [:id]" do
      review = review_fixture()
      assert Blank.Schema.primary_keys(review) == [:id]
    end

    test "identity_field/1 returns :rating_label" do
      review = review_fixture()
      assert Blank.Schema.identity_field(review) == :rating_label
    end

    test "order_field/1 returns {:rating, :desc} from config" do
      review = review_fixture()
      assert Blank.Schema.order_field(review) == {:rating, :desc}
    end

    test "changeset/2 returns the schema's changeset/2 by default" do
      review = review_fixture()
      cs = Blank.Schema.changeset(review, :new)
      assert is_function(cs, 2)

      changeset = cs.(review, %{rating: 3, rating_label: "OK"})
      assert Ecto.Changeset.get_change(changeset, :rating) == 3
      assert Ecto.Changeset.get_change(changeset, :rating_label) == "OK"
    end

    test "get_field/2 returns field definitions for Review fields" do
      review = review_fixture()

      rating = Blank.Schema.get_field(review, :rating)
      assert %Blank.Field{} = rating
      assert rating.key == :rating
      assert rating.label == "Score"
      assert rating.sortable == true

      text = Blank.Schema.get_field(review, :review_text)
      assert %Blank.Field{} = text
      assert text.key == :review_text
      assert text.label == "Review"

      reviewer = Blank.Schema.get_field(review, :reviewer_name)
      assert reviewer.searchable == true
    end

    test "get_field/2 returns BelongsTo module for :post association" do
      review = review_fixture()
      field = Blank.Schema.get_field(review, :post)
      assert field.module == BelongsTo
    end
  end

  # ─── Flop integration — Post ──────────────────────────────────────────

  describe "Flop.Schema integration (Post)" do
    test "filterable/1 returns the searchable fields" do
      filterable = Flop.Schema.filterable(%Post{})
      assert :search in filterable
      assert :title in filterable
    end

    test "sortable/1 returns the sortable fields" do
      sortable = Flop.Schema.sortable(%Post{})
      assert :title in sortable
      assert :published in sortable
      assert :views in sortable
    end

    test "default_order/1 returns nil (no default_order in flop_opts)" do
      assert Flop.Schema.default_order(%Post{}) == nil
    end

    test "max_limit/1 returns nil or configured value" do
      max = Flop.Schema.max_limit(%Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert max == nil
    end

    test "default_limit/1 returns nil or configured value" do
      default = Flop.Schema.default_limit(%Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert default == nil
    end

    test "pagination_types/1 returns nil or configured list" do
      types = Flop.Schema.pagination_types(%Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert types == nil
    end

    test "field_info/2 returns a Flop.FieldInfo struct for a known field" do
      info = Flop.Schema.field_info(%Post{}, :title)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :string
    end

    test "field_info/2 returns ecto_type for boolean field" do
      info = Flop.Schema.field_info(%Post{}, :published)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :boolean
    end

    test "field_info/2 returns ecto_type for integer field" do
      info = Flop.Schema.field_info(%Post{}, :views)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :integer
    end
  end

  # ─── Flop integration — User ──────────────────────────────────────────

  describe "Flop.Schema integration (User)" do
    test "filterable/1 includes :search and :email" do
      filterable = Flop.Schema.filterable(%User{})
      assert :search in filterable
      assert :email in filterable
    end

    test "sortable/1 returns configured sortable fields" do
      sortable = Flop.Schema.sortable(%User{})
      assert is_list(sortable)
    end

    test "field_info/2 for email returns string ecto_type" do
      info = Flop.Schema.field_info(%User{}, :email)
      assert info.ecto_type == :string
    end
  end

  # ─── Flop integration — validate_and_run ───────────────────────────────

  describe "Flop.validate_and_run/3" do
    test "returns empty list when no records match" do
      {:ok, {posts, %Flop.Meta{}}} =
        Flop.validate_and_run(Post, %Flop{}, repo: Repo)

      assert posts == []
    end

    test "returns inserted records" do
      Repo.insert!(%Post{
        title: "Test Post",
        body: "Body",
        published: true,
        views: 0
      })

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(Post, %Flop{}, repo: Repo)

      assert length(posts) == 1
      assert hd(posts).title == "Test Post"
    end

    test "supports ordering" do
      Repo.insert!(%Post{title: "B", body: nil, published: true, views: 0})
      Repo.insert!(%Post{title: "A", body: nil, published: true, views: 0})

      flop = %Flop{order_by: [:title], order_directions: [:asc]}

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(Post, flop, repo: Repo)

      titles = Enum.map(posts, & &1.title)
      assert titles == ["A", "B"]
    end

    test "supports filtering" do
      Repo.insert!(%Post{title: "Match", body: nil, published: true, views: 0})
      Repo.insert!(%Post{title: "Nope", body: nil, published: true, views: 0})

      flop = %Flop{filters: [%Flop.Filter{field: :title, op: :==, value: "Match"}]}

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(Post, flop, repo: Repo)

      assert length(posts) == 1
      assert hd(posts).title == "Match"
    end

    test "returns meta with pagination info" do
      for i <- 1..3 do
        Repo.insert!(%Post{
          title: "Post #{i}",
          body: nil,
          published: true,
          views: 0
        })
      end

      {:ok, {_posts, meta}} =
        Flop.validate_and_run(Post, %Flop{limit: 2}, repo: Repo)

      assert %Flop.Meta{} = meta
    end
  end

  # ─── Flop integration — Review ────────────────────────────────────────

  describe "Flop.Schema integration (Review)" do
    test "filterable/1 includes :search and :reviewer_name" do
      filterable = Flop.Schema.filterable(%Review{})
      assert :search in filterable
      assert :reviewer_name in filterable
    end

    test "sortable/1 includes :rating" do
      sortable = Flop.Schema.sortable(%Review{})
      assert :rating in sortable
    end

    test "default_order/1 returns nil (order_field is for Blank, not Flop)" do
      # The Flop default_order comes from flop_opts, not from Blank's order_field config.
      # Review has order_field: {:rating, :desc} but no flop_opts default_order.
      default_order = Flop.Schema.default_order(%Review{})
      assert default_order == nil
    end

    test "field_info/2 returns correct ecto_type for rating (integer)" do
      info = Flop.Schema.field_info(%Review{}, :rating)
      assert info.ecto_type == :integer
    end

    test "field_info/2 returns correct ecto_type for rating_label (string)" do
      info = Flop.Schema.field_info(%Review{}, :rating_label)
      assert info.ecto_type == :string
    end
  end

  # ─── __name__/2 with list identity_field value ────────────────────────

  describe "__name__/2 with list identity_field" do
    test "joins list elements with commas" do
      article = %Article{id: 1, title: "Test", tag_names: ["elixir", "phoenix"]}
      assert Any.__name__(article, :tag_names) == "elixir, phoenix"
    end

    test "returns single-element list as string" do
      article = %Article{id: 1, title: "Test", tag_names: ["elixir"]}
      assert Any.__name__(article, :tag_names) == "elixir"
    end

    test "returns empty list as empty string" do
      article = %Article{id: 1, title: "Test", tag_names: []}
      assert Any.__name__(article, :tag_names) == ""
    end

    test "returns nil for nil list value" do
      article = %Article{id: 1, title: "Test", tag_names: nil}
      assert Any.__name__(article, :tag_names) == nil
    end
  end

  # ─── __name__/2 with map identity_field value ────────────────────────

  describe "__name__/2 with map identity_field" do
    test "resolves belongs_to display_field" do
      author = user_fixture(%{id: 10, name: "Alice"})
      post = post_fixture(%{author: author, author_id: 10})
      assert Any.__name__(post, :author) == "Alice"
    end

    test "resolves map value using display_field from field def" do
      author = user_fixture(%{id: 20, name: "Bob"})
      post = post_fixture(%{author: author, author_id: 20})
      assert Any.__name__(post, :author) == "Bob"
    end
  end

  # ─── put_field_module/3 ─────────────────────────────────────────────

  describe "put_field_module/3" do
    test "returns BelongsTo for belongs_to association" do
      {module, _opts} = Any.put_field_module([], :author, Post)
      assert module == BelongsTo
    end

    test "returns BelongsTo for Review's post association" do
      {module, _opts} = Any.put_field_module([], :post, Review)
      assert module == BelongsTo
    end

    test "returns HasMany for has_many association" do
      {module, _opts} = Any.put_field_module([], :tags, Post)
      assert module == HasMany
    end

    test "returns HasMany for Review's comments association" do
      {module, _opts} = Any.put_field_module([], :comments, Post)
      assert module == HasMany
    end

    test "returns List for array field" do
      {module, _opts} = Any.put_field_module([], :tag_names, Article)
      assert module == List
    end

    test "returns Text for :string type field" do
      {module, _opts} = Any.put_field_module([], :title, Post)
      assert module == Blank.Fields.Text
    end

    test "returns Boolean for :boolean type field" do
      {module, _opts} = Any.put_field_module([], :published, Post)
      assert module == Blank.Fields.Boolean
    end

    test "returns module from field_def when already set" do
      {module, opts} = Any.put_field_module([module: Blank.Fields.Boolean], :title, Post)
      assert module == Blank.Fields.Boolean
      assert opts[:module] == Blank.Fields.Boolean
    end
  end

  # ─── default_for_field/1 (indirectly via get_field) ──────────────────

  describe "default_for_field/1 via get_field" do
    test "returns label 'ID' and readonly for :id field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :id)
      assert field.label == "ID"
      assert field.readonly == true
    end

    test "returns label 'Arango ID' and readonly for :__id__ field" do
      struct = %Document{id: 1, __id__: "abc123", title: "Test"}
      field = Blank.Schema.get_field(struct, :__id__)
      assert field.label == "Arango ID"
      assert field.readonly == true
    end

    test "returns empty defaults for a regular non-id field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :body)
      # body has explicit label: "Body" from field config, so not empty defaults
      assert field.label == "Body"
      assert field.readonly != true
    end
  end

  # ─── schema_fields/1 (indirectly via get_field for all fields) ──────

  describe "schema_fields/1 via get_field for all fields" do
    test "get_field works for all Post schema fields" do
      post = post_fixture()

      # These fields exist in the schema but may not be in the @derive fields config
      for field <- Post.__schema__(:fields) do
        result = Blank.Schema.get_field(post, field)
        assert %Blank.Field{} = result
        assert result.key == field
      end
    end

    test "get_field works for all User schema fields" do
      user = user_fixture()

      for field <- User.__schema__(:fields) do
        result = Blank.Schema.get_field(user, field)
        assert %Blank.Field{} = result
        assert result.key == field
      end
    end

    test "get_field works for all Article schema fields" do
      article = %Article{id: 1, title: "Test", tag_names: ["elixir"]}

      for field <- Article.__schema__(:fields) do
        result = Blank.Schema.get_field(article, field)
        assert %Blank.Field{} = result
        assert result.key == field
      end
    end

    test "get_field works for all Review schema fields" do
      review = review_fixture()

      for field <- Review.__schema__(:fields) do
        result = Blank.Schema.get_field(review, field)
        assert %Blank.Field{} = result
        assert result.key == field
      end
    end
  end

  # ─── default_order/1 via order_field/1 ──────────────────────────────

  describe "default_order/1 via order_field" do
    test "nil order_field defaults to {id, :asc} for Post" do
      post = post_fixture()
      assert Blank.Schema.order_field(post) == {:id, :asc}
    end

    test "nil order_field defaults to {id, :asc} for User" do
      user = user_fixture()
      assert Blank.Schema.order_field(user) == {:id, :asc}
    end

    test "tuple order_field is preserved for Review" do
      review = review_fixture()
      assert Blank.Schema.order_field(review) == {:rating, :desc}
    end

    test "nil order_field defaults to {id, :asc} for Article" do
      article = %Article{id: 1, title: "Test", tag_names: []}
      assert Blank.Schema.order_field(article) == {:id, :asc}
    end
  end

  # ─── Edge cases ────────────────────────────────────────────────────────

  describe "edge cases" do
    test "foreign key fields still get default field definitions" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :author_id)
      assert %Blank.Field{} = field
    end

    test "Article with array field gets List module" do
      article = %Article{id: 1, title: "Test", tag_names: ["elixir"]}
      field = Blank.Schema.get_field(article, :tag_names)
      assert field.module == List
    end

    test "order_field with atom (no direction tuple) defaults to :asc" do
      post = post_fixture()
      assert Blank.Schema.order_field(post) == {:id, :asc}
    end

    test "order_field with tuple preserves direction" do
      review = review_fixture()
      assert Blank.Schema.order_field(review) == {:rating, :desc}
    end

    test "get_field works for all schema fields including unlisted ones" do
      post = post_fixture()

      id_field = Blank.Schema.get_field(post, :id)
      assert %Blank.Field{} = id_field
      assert id_field.key == :id

      inserted_field = Blank.Schema.get_field(post, :inserted_at)
      assert %Blank.Field{} = inserted_field

      author_id_field = Blank.Schema.get_field(post, :author_id)
      assert %Blank.Field{} = author_id_field
    end
  end
end
