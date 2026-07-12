defmodule DemoApp.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:demo_app_orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :customer_name, :string, null: false
      add :total_amount, :decimal, null: false
      add :status, :string, default: "pending"
      add :user_id, references(:demo_app_users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:demo_app_orders, [:user_id])
  end
end
