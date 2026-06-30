defmodule TestApp.Repo.Migrations.CreateTestAppPosts do
  use Ecto.Migration

  def change do
    create table(:test_app_posts) do
      add(:title, :string, null: false)
      add(:body, :text)
      add(:published, :boolean, default: false, null: false)
      add(:views, :integer, default: 0)
      add(:published_at, :utc_datetime)
      add(:author_id, references(:test_app_users, on_delete: :nilify_all))

      timestamps()
    end

    create(index(:test_app_posts, [:author_id]))
    create(index(:test_app_posts, [:published]))
  end
end
