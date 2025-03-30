if Code.ensure_loaded?(ArangoXEcto.Schema) do
  defmodule Blank.Accounts.AdminToken do
    use ArangoXEcto.Schema

    schema "blank_admins_tokens" do
      field(:token, :string)
      field(:context, :string)
      field(:sent_to, :string)
      belongs_to(:admin, Blank.Accounts.Admin)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    defdelegate build_session_token(admin), to: Blank.Accounts.AdminTokenBase
    defdelegate verify_session_token_query(token), to: Blank.Accounts.AdminTokenBase
    defdelegate by_token_and_context_query(token, context), to: Blank.Accounts.AdminTokenBase
    defdelegate by_admin_and_contexts_query(admin, content), to: Blank.Accounts.AdminTokenBase
  end
else
  defmodule Blank.Accounts.AdminToken do
    use Ecto.Schema

    schema "blank_admins_tokens" do
      field(:token, :binary)
      field(:context, :string)
      field(:sent_to, :string)
      belongs_to(:admin, Blank.Accounts.Admin)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    defdelegate build_session_token(admin), to: Blank.Accounts.AdminTokenBase
    defdelegate verify_session_token_query(token), to: Blank.Accounts.AdminTokenBase
    defdelegate by_token_and_context_query(token, context), to: Blank.Accounts.AdminTokenBase
    defdelegate by_admin_and_contexts_query(admin, content), to: Blank.Accounts.AdminTokenBase
  end
end
