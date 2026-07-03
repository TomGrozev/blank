defmodule Blank.Repo.Migrations.AddAuditActorAndExtra do
  use Ecto.Migration

  def change do
    alter table(:blank_audit_logs) do
      add :actor_display_name, :string
      add :actor_email, :string
      add :extra, :map
    end
  end
end
