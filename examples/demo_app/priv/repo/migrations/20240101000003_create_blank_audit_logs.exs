defmodule DemoApp.Repo.Migrations.CreateBlankAuditLogs do
  use Ecto.Migration

  def change do
    create table(:blank_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :string
      add :params, :map
      add :admin_id, :binary_id
      add :ip_address, :string

      timestamps(type: :utc_datetime)
    end

    create index(:blank_audit_logs, [:admin_id])
    create index(:blank_audit_logs, [:resource_type, :resource_id])
  end
end
