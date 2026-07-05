defmodule Blank.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:blank_users) do
      add :email, :citext
      add :name, :string
      add :hashed_password, :string
      add :provider, :string
      add :external_uid, :string
      add :roles, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blank_users, [:provider, :external_uid])
    create unique_index(:blank_users, [:email], where: "provider IS NULL")

    create table(:blank_users_tokens) do
      add :user_id, references(:blank_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:blank_users_tokens, [:user_id])
    create unique_index(:blank_users_tokens, [:context, :token])
  end
end
