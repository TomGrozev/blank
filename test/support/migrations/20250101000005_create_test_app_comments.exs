defmodule TestApp.Repo.Migrations.CreateTestAppComments do
  use Ecto.Migration

  def change do
    create table(:test_app_comments) do
      add(:body, :text, null: false)
      add(:post_id, references(:test_app_posts, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:test_app_comments, [:post_id]))
  end
end
