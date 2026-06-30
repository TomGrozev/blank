defmodule TestApp.Repo.Migrations.CreateTestAppReviews do
  use Ecto.Migration

  def change do
    create table(:test_app_reviews) do
      add(:rating, :integer, null: false)
      add(:rating_label, :string, null: false)
      add(:review_text, :text)
      add(:reviewer_name, :string)
      add(:post_id, references(:test_app_posts, on_delete: :delete_all))

      timestamps()
    end

    create(index(:test_app_reviews, [:post_id]))
  end
end
