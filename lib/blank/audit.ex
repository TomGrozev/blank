defmodule Blank.Audit do
  import Ecto.Query

  alias Blank.Audit.AuditLog

  @doc """
  Lists all audits
  """
  def list_all(opts \\ []) do
    user_schema = Application.get_env(:blank, :user_module, Blank.Accounts.Admin)
    struct = struct(user_schema)
    identity_field = Blank.Schema.identity_field(struct)

    fields =
      [identity_field]
      |> Stream.uniq()
      |> Enum.map(&{&1, Blank.Schema.get_field(struct, &1)})

    repo().all(
      from(a in AuditLog,
        where: ^Keyword.get(opts, :where, []),
        order_by: [desc: :inserted_at],
        preload: [:admin, [user: ^Blank.Context.list_query(user_schema, fields)]],
        limit: ^Keyword.get(opts, :limit, 50)
      )
    )
  end

  @doc """
  Lists all audits for user
  """
  def list_all_for_user(user_or_id, opts \\ [])
  def list_all_for_user(%{id: id}, opts), do: list_all_for_user(id, opts)

  def list_all_for_user(id, opts) when is_binary(id) or is_integer(id) do
    user_schema = Application.get_env(:blank, :user_module, Blank.Accounts.Admin)
    struct = struct(user_schema)
    identity_field = Blank.Schema.identity_field(struct)

    fields =
      [identity_field]
      |> Stream.uniq()
      |> Enum.map(&{&1, Blank.Schema.get_field(struct, &1)})

    repo().all(
      from(a in AuditLog,
        join: u in assoc(a, :user),
        where: u.id == ^id,
        where: ^Keyword.get(opts, :where, []),
        order_by: [desc: :inserted_at],
        preload: [:admin, [user: ^Blank.Context.list_query(user_schema, fields)]],
        limit: ^Keyword.get(opts, :limit, 50)
      )
    )
  end

  @doc """
  Lists audits by the system
  """
  def list_all_from_system(clauses \\ []) do
    repo().all(
      from(a in AuditLog,
        where:
          is_nil(a.admin_id) and is_nil(a.user_id) and
            a.user_agent ==
              "SYSTEM",
        where: ^clauses,
        order_by: [desc: :inserted_at],
        preload: [:admin, :user]
      )
    )
  end

  @doc """
  Delete all logs
  """
  def delete_all(audit_context) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all, AuditLog)
    |> multi(audit_context, "audit_logs.delete_all", %{})
    |> repo().transaction()
  end

  @doc """
  Create an audit log
  """
  def log!(audit_context, action, params) do
    AuditLog.build!(audit_context, action, params)
    |> repo().insert!()
  end

  @doc """
  Create an audit log as part of a multi operation
  """
  def multi(multi, audit_context, action, fun) when is_function(fun, 2) do
    Ecto.Multi.run(multi, :audit, fn repo, results ->
      audit_log = AuditLog.build!(fun.(audit_context, results), action, %{})
      {:ok, repo.insert!(audit_log)}
    end)
  end

  def multi(multi, audit_context, action, params) do
    Ecto.Multi.insert(multi, :audit, fn _ ->
      AuditLog.build!(audit_context, action, params)
    end)
  end

  defp repo, do: Application.fetch_env!(:blank, :repo)
end
