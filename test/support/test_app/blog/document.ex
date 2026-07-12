defmodule TestApp.Blog.Document do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    identity_field: :title,
    fields: [
      title: [searchable: true]
    ]
  }

  schema "test_app_documents" do
    field :__id__, :string
    field :title, :string
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:__id__, :title])
    |> validate_required([:title])
  end
end
