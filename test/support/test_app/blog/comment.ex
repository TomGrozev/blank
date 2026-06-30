defmodule TestApp.Blog.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "test_app_comments" do
    field :body, :string
    belongs_to :post, TestApp.Blog.Post

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :post_id])
    |> validate_required([:body])
  end
end
