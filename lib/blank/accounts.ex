defmodule Blank.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Blank.Accounts.{User, UserToken}
  alias Blank.Audit

  @doc """
  Get all users
  """
  @spec list_users() :: [User.t()]
  def list_users do
    repo().all(User)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> {:ok, _user} = register_user(%{email: "foo@example.com", password: "Str0ng!Passw0rd"})
      iex> get_user_by_email("foo@example.com") |> is_struct(Blank.Accounts.User)
      true

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    repo().get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> {:ok, _user} = register_user(%{email: "auth@example.com", password: "Str0ng!Passw0rd"})
      iex> get_user_by_email_and_password("auth@example.com", "Str0ng!Passw0rd") |> is_struct(Blank.Accounts.User)
      true

      iex> get_user_by_email_and_password("auth@example.com", "invalid_password")
      nil

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) ::
          User.t()
          | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = repo().get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> {:ok, user} = register_user(%{email: "get_user@example.com", password: "Str0ng!Passw0rd"})
      iex> get_user!(user.id) |> is_struct(Blank.Accounts.User)
      true

  """
  @spec get_user!(integer()) :: User.t()
  def get_user!(id), do: repo().get!(User, id)

  ## User Registration

  @doc """
  Registers a user.

  For available options refer to
  `Blank.Accounts.User.registration_changeset/3`

  ## Examples

      iex> {:ok, user} = register_user(%{email: "user@example.com", password: "Str0ng!Passw0rd"})
      iex> match?(%Blank.Accounts.User{}, user)
      true

      iex> {:error, changeset} = register_user(%{email: "bad"})
      iex> changeset.valid?
      false

  """
  @spec register_user(map(), Keyword.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs, opts \\ []) do
    %User{}
    |> User.registration_changeset(attrs, opts)
    |> repo().insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(%Blank.Accounts.User{}) |> is_struct(Ecto.Changeset)
      true

  """
  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  @doc """
  Gets a user by provider and external UID.
  """
  @spec get_user_by_provider_and_uid(atom(), String.t()) :: User.t() | nil
  def get_user_by_provider_and_uid(provider, external_uid)
      when is_atom(provider) and is_binary(external_uid) do
    repo().get_by(User, provider: Atom.to_string(provider), external_uid: external_uid)
  end

  @doc """
  Creates a user from ueberauth data.
  """
  @spec create_ueberauth_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_ueberauth_user(attrs) do
    %User{}
    |> User.ueberauth_changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Refreshes email and name for an existing ueberauth user.
  """
  @spec refresh_ueberauth_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def refresh_ueberauth_user(%User{} = user, attrs) do
    user
    |> User.ueberauth_changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> {:ok, user} = register_user(%{email: "to_delete@example.com", password: "Str0ng!Passw0rd"})
      iex> {:ok, deleted} = delete_user(user)
      iex> match?(%Blank.Accounts.User{}, deleted)
      true

  """
  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    repo().delete(user)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(%Blank.Accounts.User{}) |> is_struct(Ecto.Changeset)
      true

  """
  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> {:ok, user} = register_user(%{email: "pw_update@example.com", password: "OldP4ssword123!"})
      iex> {:ok, updated} = update_user_password(user, "OldP4ssword123!", %{password: "N3w!Password123"})
      iex> match?(%Blank.Accounts.User{}, updated)
      true

  """
  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()}
          | {:error, Ecto.Changeset.t()}
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> repo().transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(User.t()) :: String.t()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    repo().insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  @spec get_user_by_session_token(String.t()) :: User.t()
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    repo().one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(String.t()) :: :ok
  def delete_user_session_token(token) do
    repo().delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Updates a user's roles and emits an audit log entry.

  Wraps the role update and audit emission in an `Ecto.Multi`, calling
  `Blank.Audit.multi/4` to record the change.

  `opts` must include:
    * `:source` - a string identifying the origin of the change (e.g. `"admin_ui"`)
    * `:audit_context` - a `Blank.Audit.AuditLog` struct

  ## Examples

      update_roles(user, [:admin, :editor], source: "admin_ui", audit_context: audit_log)
      #=> {:ok, %User{roles: [:admin, :editor]}}

  """
  @spec update_roles(User.t(), [atom()], Keyword.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_roles(%User{} = user, roles, opts) do
    before_roles = user.roles
    source = Keyword.fetch!(opts, :source)
    audit_context = Keyword.fetch!(opts, :audit_context)

    changeset = Ecto.Changeset.cast(user, %{roles: roles}, [:roles])

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Audit.multi(audit_context, "accounts.roles_updated", fn audit_log, %{user: updated_user} ->
      %{
        audit_log
        | params: %{
            user_id: updated_user.id,
            roles: updated_user.roles,
            before_roles: before_roles,
            source: source
          }
      }
    end)
    |> repo().transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  defp repo, do: Application.fetch_env!(:blank, :repo)
end
