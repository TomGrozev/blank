defmodule Blank.Accounts.AdminToken do
  use Ecto.Schema
  import Ecto.Query
  alias Blank.Accounts.AdminToken

  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @session_validity_in_days 60

  schema "blank_admins_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    belongs_to(:admin, Blank.Accounts.Admin)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual admin
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(admin) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %AdminToken{token: token, context: "session", admin_id: admin.id}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the admin found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from(token in by_token_and_context_query(token, "session"),
        join: admin in assoc(token, :admin),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: admin
      )

    {:ok, query}
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def by_token_and_context_query(token, context) do
    from(AdminToken, where: [token: ^token, context: ^context])
  end

  @doc """
  Gets all tokens for the given admin for the given contexts.
  """
  def by_admin_and_contexts_query(admin, :all) do
    from(t in AdminToken, where: t.admin_id == ^admin.id)
  end

  def by_admin_and_contexts_query(admin, [_ | _] = contexts) do
    from(t in AdminToken, where: t.admin_id == ^admin.id and t.context in ^contexts)
  end
end
