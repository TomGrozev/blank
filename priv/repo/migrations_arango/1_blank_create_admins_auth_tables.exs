defmodule Blank.Repo.Migrations.CreateAdminsAuthTables do
  use ArangoXEcto.Migration

  def change do
    create collection(:blank_admins) do
      add :email, :string, format: :email, null: false
      add :hashed_password, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blank_admins, [:email])

    create collection(:blank_admins_tokens) do
      add :admin_id, :string, null: false
      add :token, :string, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:blank_admins_tokens, [:admin_id])
    create unique_index(:blank_admins_tokens, [:context, :token])
  end
end

