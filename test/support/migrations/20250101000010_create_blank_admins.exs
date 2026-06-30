defmodule TestApp.Repo.Migrations.CreateBlankAdmins do
  use Ecto.Migration

  def change do
    create table(:blank_admins) do
      add(:email, :string, null: false)
      add(:hashed_password, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:blank_admins, [:email]))
  end
end
