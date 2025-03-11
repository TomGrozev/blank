defmodule Blank.Repo.Migrations.CreateAdminsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:blank_admins) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blank_admins, [:email])

    create table(:blank_admins_tokens) do
      add :admin_id, references(:blank_admins, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:blank_admins_tokens, [:admin_id])
    create unique_index(:blank_admins_tokens, [:context, :token])
  end
end

