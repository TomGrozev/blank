defmodule TestApp.Repo.Migrations.CreateTestAppArticles do
  use Ecto.Migration

  def change do
    create table(:test_app_articles) do
      add(:title, :string, null: false)
      add(:tag_names, {:array, :string}, default: [])
      timestamps()
    end
  end
end
