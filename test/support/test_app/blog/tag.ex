defmodule TestApp.Blog.Tag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "test_app_tags" do
    field :name, :string
    belongs_to :post, TestApp.Blog.Post

    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :post_id])
    |> validate_required([:name])
  end
end
