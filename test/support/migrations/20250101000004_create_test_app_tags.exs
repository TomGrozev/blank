defmodule TestApp.Repo.Migrations.CreateTestAppTags do
  use Ecto.Migration

  def change do
    create table(:test_app_tags) do
      add(:name, :string, null: false)
      add(:post_id, references(:test_app_posts, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:test_app_tags, [:post_id]))
  end
end
