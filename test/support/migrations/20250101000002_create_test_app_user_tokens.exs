defmodule TestApp.Repo.Migrations.CreateTestAppUserTokens do
  use Ecto.Migration

  def change do
    create table(:test_app_user_tokens) do
      add(:user_id, references(:test_app_users, on_delete: :delete_all), null: false)
      add(:token, :binary, null: false)
      add(:context, :string, null: false)

      timestamps(updated_at: false)
    end

    create(index(:test_app_user_tokens, [:user_id]))
  end
end
