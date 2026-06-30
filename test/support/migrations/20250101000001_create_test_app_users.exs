defmodule TestApp.Repo.Migrations.CreateTestAppUsers do
  use Ecto.Migration

  def change do
    create table(:test_app_users) do
      add(:email, :string, null: false)
      add(:name, :string)
      timestamps()
    end

    create(unique_index(:test_app_users, [:email]))
  end
end
