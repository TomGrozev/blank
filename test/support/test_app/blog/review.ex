defmodule TestApp.Blog.Review do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    identity_field: :rating_label,
    order_field: {:rating, :desc},
    fields: [
      rating: [label: "Score", sortable: true],
      review_text: [label: "Review"],
      reviewer_name: [searchable: true]
    ]
  }

  schema "test_app_reviews" do
    field :rating, :integer
    field :rating_label, :string
    field :review_text, :string
    field :reviewer_name, :string
    belongs_to :post, TestApp.Blog.Post

    timestamps()
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:rating, :rating_label, :review_text, :reviewer_name, :post_id])
    |> validate_required([:rating, :rating_label])
  end
end
