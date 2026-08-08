defmodule TestApp.Repo.Migrations.CreateBlankUsersTokens do
  use Ecto.Migration

  def change do
    create table(:blank_users_tokens) do
      add(:user_id, references(:blank_users, on_delete: :delete_all), null: false)
      add(:token, :binary, null: false)
      add(:context, :string, null: false)
      add(:sent_to, :string)
      add(:last_activity_at, :utc_datetime)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create(index(:blank_users_tokens, [:user_id]))
    create(unique_index(:blank_users_tokens, [:context, :token]))
  end
end
