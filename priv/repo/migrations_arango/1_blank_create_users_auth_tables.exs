defmodule Blank.Repo.Migrations.CreateUsersAuthTables do
  use ArangoXEcto.Migration

  def change do
    create collection(:blank_users) do
      add :email, :string, format: :email
      add :name, :string
      add :hashed_password, :string
      add :provider, :string
      add :external_uid, :string
      add :roles, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blank_users, [:provider, :external_uid])

    create collection(:blank_users_tokens) do
      add :user_id, :string, null: false
      add :token, :string, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :last_activity_at, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:blank_users_tokens, [:user_id])
    create unique_index(:blank_users_tokens, [:context, :token])
  end
end
