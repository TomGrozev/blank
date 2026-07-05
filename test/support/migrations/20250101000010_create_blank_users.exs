defmodule TestApp.Repo.Migrations.CreateBlankUsers do
  use Ecto.Migration

  def change do
    create table(:blank_users) do
      add(:email, :string)
      add(:name, :string)
      add(:hashed_password, :string)
      add(:provider, :string)
      add(:external_uid, :string)
      add(:roles, {:array, :string}, null: false, default: [])

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:blank_users, [:provider, :external_uid]))
    create(unique_index(:blank_users, [:email], where: "provider IS NULL"))
  end
end
