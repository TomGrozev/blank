defmodule TestApp.Blog.Article do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    identity_field: :title,
    fields: [
      title: [searchable: true, sortable: true],
      tag_names: [searchable: true, sortable: true]
    ]
  }

  schema "test_app_articles" do
    field :title, :string
    field :tag_names, {:array, :string}, default: []
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :tag_names])
    |> validate_required([:title])
  end
end
