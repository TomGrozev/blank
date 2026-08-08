defmodule Blank.Repo.Migrations.CreateAuditLog do
  use ArangoXEcto.Migration

  def change do
    create table(:blank_audit_logs) do
      add :action, :string, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :params, :map, null: false
      add :user_id, :string
      add :actor_display_name, :string
      add :actor_email, :string
      add :extra, :map
      timestamps(updated_at: false)
    end

    create index(:blank_audit_logs, [:user_id])
  end
end
