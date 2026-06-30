defmodule TestAppWeb.Admin.PostLive do
  @moduledoc false
  alias TestApp.Blog.Post

  use Blank.AdminPage,
    schema: Post,
    icon: "hero-document",
    index_fields: [:title, :published, :author],
    show_fields: [:title, :body, :published, :author, :tags, :comments],
    edit_fields: [:title, :body, :published, :author],
    name: "post",
    plural_name: "posts"

  # Override stat_query to use count(i.id) instead of count(i) which
  # is incompatible with SQLite3 (requires a column name, not a struct).
  @impl Blank.AdminPage
  def stat_query(:total, query) do
    import Ecto.Query
    {:query, from(i in subquery(query), select: count(i.id))}
  end
end
