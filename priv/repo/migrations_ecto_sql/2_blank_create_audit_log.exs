defmodule Blank.Repo.Migrations.CreateAuditLog do
  use Ecto.Migration

  def change do
    create table(:blank_audit_logs) do
      add :action, :string, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :params, :map, null: false
      add :user_id, references(Application.get_env(:blank, :user_table, :users), on_delete: :nothing, column: Application.get_env(:blank, :user_table_pk, :id), type: Application.get_env(:blank, :user_table_pk_type, :bigserial))
      add :admin_id, references(:blank_admins, on_delete: :nilify_all)
      timestamps(updated_at: false)
    end

    create index(:blank_audit_logs, [:user_id])
    create index(:blank_audit_logs, [:admin_id])
  end
end

