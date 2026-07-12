defmodule TestApp.Repo.Migrations.CreateTestAppDocuments do
  use Ecto.Migration

  def change do
    create table(:test_app_documents) do
      add(:__id__, :string)
      add(:title, :string)
    end
  end
end
