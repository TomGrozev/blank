defmodule DemoApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:demo_app_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :status, :string, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:demo_app_users, [:email])
  end
end
