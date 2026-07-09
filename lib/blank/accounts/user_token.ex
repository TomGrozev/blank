defmodule Blank.Accounts.UserToken do
  @moduledoc """
  Schema for password reset / session tokens used by Blank.

  Stores hashed tokens in the `blank_users_tokens` table. Each token has a
  `:context` (`"session"`) and a `:sent_to` field, and belongs to a User.
  """

  use Blank.EctoSchema

  import Ecto.Query
  alias Blank.Accounts.UserToken
  alias Blank.Accounts.User

  @type t :: %{
          token: binary(),
          context: String.t(),
          sent_to: String.t(),
          user: User.t(),
          inserted_at: DateTime.t()
        }

  schema "blank_users_tokens" do
    field(:token, @binary_type)
    field(:context, :string)
    field(:sent_to, :string)
    field(:last_activity_at, :utc_datetime)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @session_validity_in_days 60

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

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  @spec build_session_token(User.t()) :: {binary(), t()}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size) |> Base.encode64()

    {token,
     %UserToken{
       token: token,
       context: "session",
       user_id: user.id,
       last_activity_at: DateTime.truncate(DateTime.utc_now(), :second)
     }}
  end

  @doc """
  Touches the last_activity_at field of a token to record current activity.
  """
  @spec touch_last_activity(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def touch_last_activity(%UserToken{} = token) do
    repo = Application.fetch_env!(:blank, :repo)

    token
    |> Ecto.Changeset.change(%{last_activity_at: DateTime.truncate(DateTime.utc_now(), :second)})
    |> repo.update()
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  @spec verify_session_token_query(binary()) :: {:ok, Ecto.Query.t()}
  def verify_session_token_query(token) do
    query =
      from(token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user
      )

    {:ok, query}
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  @spec by_token_and_context_query(binary(), String.t()) :: Ecto.Query.t()
  def by_token_and_context_query(token, context) do
    from(UserToken, where: [token: ^token, context: ^context])
  end

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  @spec by_user_and_contexts_query(User.t(), :all | [String.t()]) :: Ecto.Query.t()
  def by_user_and_contexts_query(user, :all) do
    from(t in UserToken, where: t.user_id == ^user.id)
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from(t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts)
  end
end
