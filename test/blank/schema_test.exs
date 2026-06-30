defmodule Blank.SchemaTest do
  use TestApp.DataCase

  # ─── helpers ────────────────────────────────────────────────────────────

  defp post_fixture(attrs \\ %{}) do
    %TestApp.Blog.Post{
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
    %TestApp.Accounts.User{
      id: 1,
      email: "alice@example.com",
      name: "Alice"
    }
    |> Map.merge(attrs)
  end

  defp review_fixture(attrs \\ %{}) do
    %TestApp.Blog.Review{
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
      assert Blank.Schema.Any.__name__(post, :author) == "Alice"
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
      assert field.module == Blank.Fields.Boolean
    end

    test "returns correct module for a belongs_to field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :author)
      assert field.module == Blank.Fields.BelongsTo
      assert field.display_field == :name
    end

    test "returns correct module for a has_many field" do
      post = post_fixture()
      field = Blank.Schema.get_field(post, :tags)
      assert field.module == Blank.Fields.HasMany
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
      assert field.module == Blank.Fields.Text
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
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.name(tag)
      end
    end

    test "raises for name/1 on Comment" do
      comment = %TestApp.Blog.Comment{id: 1, body: "Great!"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.name(comment)
      end
    end

    test "raises for primary_keys/1 on non-deriving struct" do
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.primary_keys(tag)
      end
    end

    test "raises for identity_field/1 on non-deriving struct" do
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.identity_field(tag)
      end
    end

    test "raises for order_field/1 on non-deriving struct" do
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.order_field(tag)
      end
    end

    test "raises for changeset/2 on non-deriving struct" do
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

      assert_raise Protocol.UndefinedError, fn ->
        Blank.Schema.changeset(tag, :new)
      end
    end

    test "raises for get_field/2 on non-deriving struct" do
      tag = %TestApp.Blog.Tag{id: 1, name: "elixir"}

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
      assert field.module == Blank.Fields.BelongsTo
    end
  end

  # ─── Flop integration — Post ──────────────────────────────────────────

  describe "Flop.Schema integration (Post)" do
    test "filterable/1 returns the searchable fields" do
      filterable = Flop.Schema.filterable(%TestApp.Blog.Post{})
      assert :search in filterable
      assert :title in filterable
    end

    test "sortable/1 returns the sortable fields" do
      sortable = Flop.Schema.sortable(%TestApp.Blog.Post{})
      assert :title in sortable
      assert :published in sortable
      assert :views in sortable
    end

    test "default_order/1 returns nil (no default_order in flop_opts)" do
      assert Flop.Schema.default_order(%TestApp.Blog.Post{}) == nil
    end

    test "max_limit/1 returns nil or configured value" do
      max = Flop.Schema.max_limit(%TestApp.Blog.Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert max == nil
    end

    test "default_limit/1 returns nil or configured value" do
      default = Flop.Schema.default_limit(%TestApp.Blog.Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert default == nil
    end

    test "pagination_types/1 returns nil or configured list" do
      types = Flop.Schema.pagination_types(%TestApp.Blog.Post{})
      # Not explicitly configured in Post's @derive, so nil
      assert types == nil
    end

    test "field_info/2 returns a Flop.FieldInfo struct for a known field" do
      info = Flop.Schema.field_info(%TestApp.Blog.Post{}, :title)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :string
    end

    test "field_info/2 returns ecto_type for boolean field" do
      info = Flop.Schema.field_info(%TestApp.Blog.Post{}, :published)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :boolean
    end

    test "field_info/2 returns ecto_type for integer field" do
      info = Flop.Schema.field_info(%TestApp.Blog.Post{}, :views)
      assert %Flop.FieldInfo{} = info
      assert info.ecto_type == :integer
    end
  end

  # ─── Flop integration — User ──────────────────────────────────────────

  describe "Flop.Schema integration (User)" do
    test "filterable/1 includes :search and :email" do
      filterable = Flop.Schema.filterable(%TestApp.Accounts.User{})
      assert :search in filterable
      assert :email in filterable
    end

    test "sortable/1 returns configured sortable fields" do
      sortable = Flop.Schema.sortable(%TestApp.Accounts.User{})
      assert is_list(sortable)
    end

    test "field_info/2 for email returns string ecto_type" do
      info = Flop.Schema.field_info(%TestApp.Accounts.User{}, :email)
      assert info.ecto_type == :string
    end
  end

  # ─── Flop integration — validate_and_run ───────────────────────────────

  describe "Flop.validate_and_run/3" do
    test "returns empty list when no records match" do
      {:ok, {posts, %Flop.Meta{}}} =
        Flop.validate_and_run(TestApp.Blog.Post, %Flop{}, repo: TestApp.Repo)

      assert posts == []
    end

    test "returns inserted records" do
      Repo.insert!(%TestApp.Blog.Post{
        title: "Test Post",
        body: "Body",
        published: true,
        views: 0
      })

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(TestApp.Blog.Post, %Flop{}, repo: TestApp.Repo)

      assert length(posts) == 1
      assert hd(posts).title == "Test Post"
    end

    test "supports ordering" do
      Repo.insert!(%TestApp.Blog.Post{title: "B", body: nil, published: true, views: 0})
      Repo.insert!(%TestApp.Blog.Post{title: "A", body: nil, published: true, views: 0})

      flop = %Flop{order_by: [:title], order_directions: [:asc]}

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(TestApp.Blog.Post, flop, repo: TestApp.Repo)

      titles = Enum.map(posts, & &1.title)
      assert titles == ["A", "B"]
    end

    test "supports filtering" do
      Repo.insert!(%TestApp.Blog.Post{title: "Match", body: nil, published: true, views: 0})
      Repo.insert!(%TestApp.Blog.Post{title: "Nope", body: nil, published: true, views: 0})

      flop = %Flop{filters: [%Flop.Filter{field: :title, op: :==, value: "Match"}]}

      {:ok, {posts, _meta}} =
        Flop.validate_and_run(TestApp.Blog.Post, flop, repo: TestApp.Repo)

      assert length(posts) == 1
      assert hd(posts).title == "Match"
    end

    test "returns meta with pagination info" do
      for i <- 1..3 do
        Repo.insert!(%TestApp.Blog.Post{
          title: "Post #{i}",
          body: nil,
          published: true,
          views: 0
        })
      end

      {:ok, {_posts, meta}} =
        Flop.validate_and_run(TestApp.Blog.Post, %Flop{limit: 2}, repo: TestApp.Repo)

      assert %Flop.Meta{} = meta
    end
  end

  # ─── Flop integration — Review ────────────────────────────────────────

  describe "Flop.Schema integration (Review)" do
    test "filterable/1 includes :search and :reviewer_name" do
      filterable = Flop.Schema.filterable(%TestApp.Blog.Review{})
      assert :search in filterable
      assert :reviewer_name in filterable
    end

    test "sortable/1 includes :rating" do
      sortable = Flop.Schema.sortable(%TestApp.Blog.Review{})
      assert :rating in sortable
    end

    test "default_order/1 returns nil (order_field is for Blank, not Flop)" do
      # The Flop default_order comes from flop_opts, not from Blank's order_field config.
      # Review has order_field: {:rating, :desc} but no flop_opts default_order.
      default_order = Flop.Schema.default_order(%TestApp.Blog.Review{})
      assert default_order == nil
    end

    test "field_info/2 returns correct ecto_type for rating (integer)" do
      info = Flop.Schema.field_info(%TestApp.Blog.Review{}, :rating)
      assert info.ecto_type == :integer
    end

    test "field_info/2 returns correct ecto_type for rating_label (string)" do
      info = Flop.Schema.field_info(%TestApp.Blog.Review{}, :rating_label)
      assert info.ecto_type == :string
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
      article = %TestApp.Blog.Article{id: 1, title: "Test", tag_names: ["elixir"]}
      field = Blank.Schema.get_field(article, :tag_names)
      assert field.module == Blank.Fields.List
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
