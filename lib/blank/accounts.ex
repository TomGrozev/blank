defmodule Blank.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Blank.Accounts.{Admin, AdminToken}

  @doc """
  Get all admins
  """
  @spec list_admins() :: [Admin.t()]
  def list_admins do
    repo().all(Admin)
  end

  @doc """
  Gets an admin by email.

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "foo@example.com", password: "Str0ng!Passw0rd"})
      iex> get_admin_by_email("foo@example.com") |> is_struct(Blank.Accounts.Admin)
      true

      iex> get_admin_by_email("unknown@example.com")
      nil

  """
  @spec get_admin_by_email(String.t()) :: Admin.t() | nil
  def get_admin_by_email(email) when is_binary(email) do
    repo().get_by(Admin, email: email)
  end

  @doc """
  Gets an admin by email and password.

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "auth@example.com", password: "Str0ng!Passw0rd"})
      iex> get_admin_by_email_and_password("auth@example.com", "Str0ng!Passw0rd") |> is_struct(Blank.Accounts.Admin)
      true

      iex> get_admin_by_email_and_password("auth@example.com", "invalid_password")
      nil

  """
  @spec get_admin_by_email_and_password(String.t(), String.t()) ::
          Admin.t()
          | nil
  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = repo().get_by(Admin, email: email)
    if Admin.valid_password?(admin, password), do: admin
  end

  @doc """
  Gets a single admin.

  Raises `Ecto.NoResultsError` if the Admin does not exist.

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "get_admin@example.com", password: "Str0ng!Passw0rd"})
      iex> get_admin!(admin.id) |> is_struct(Blank.Accounts.Admin)
      true

  """
  @spec get_admin!(integer()) :: Admin.t()
  def get_admin!(id), do: repo().get!(Admin, id)

  ## Admin Registration

  @doc """
  Registers an admin.

  For available options refer to
  `Blank.Accounts.Admin.registration_changeset/3`

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "admin@example.com", password: "Str0ng!Passw0rd"})
      iex> match?(%Blank.Accounts.Admin{}, admin)
      true

      iex> {:error, changeset} = register_admin(%{email: "bad"})
      iex> changeset.valid?
      false

  """
  @spec register_admin(map(), Keyword.t()) :: {:ok, Admin.t()} | {:error, Ecto.Changeset.t()}
  def register_admin(attrs, opts \\ []) do
    %Admin{}
    |> Admin.registration_changeset(attrs, opts)
    |> repo().insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking admin changes.

  ## Examples

      iex> change_admin_registration(%Blank.Accounts.Admin{}) |> is_struct(Ecto.Changeset)
      true

  """
  @spec change_admin_registration(Admin.t(), map()) :: Ecto.Changeset.t()
  def change_admin_registration(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs, hash_password: false, validate_email: false)
  end

  @doc """
  Deletes an admin.

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "to_delete@example.com", password: "Str0ng!Passw0rd"})
      iex> {:ok, deleted} = delete_admin(admin)
      iex> match?(%Blank.Accounts.Admin{}, deleted)
      true

  """
  @spec delete_admin(Admin.t()) :: {:ok, Admin.t()} | {:error, Ecto.Changeset.t()}
  def delete_admin(%Admin{} = admin) do
    repo().delete(admin)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the admin password.

  ## Examples

      iex> change_admin_password(%Blank.Accounts.Admin{}) |> is_struct(Ecto.Changeset)
      true

  """
  @spec change_admin_password(Admin.t(), map()) :: Ecto.Changeset.t()
  def change_admin_password(admin, attrs \\ %{}) do
    Admin.password_changeset(admin, attrs, hash_password: false)
  end

  @doc """
  Updates the admin password.

  ## Examples

      iex> {:ok, admin} = register_admin(%{email: "pw_update@example.com", password: "OldP4ssword123!"})
      iex> {:ok, updated} = update_admin_password(admin, "OldP4ssword123!", %{password: "N3w!Password123"})
      iex> match?(%Blank.Accounts.Admin{}, updated)
      true

  """
  @spec update_admin_password(Admin.t(), String.t(), map()) ::
          {:ok, Admin.t()}
          | {:error, Ecto.Changeset.t()}
  def update_admin_password(admin, password, attrs) do
    changeset =
      admin
      |> Admin.password_changeset(attrs)
      |> Admin.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:admin, changeset)
    |> Ecto.Multi.delete_all(:tokens, AdminToken.by_admin_and_contexts_query(admin, :all))
    |> repo().transaction()
    |> case do
      {:ok, %{admin: admin}} -> {:ok, admin}
      {:error, :admin, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  @spec generate_admin_session_token(Admin.t()) :: String.t()
  def generate_admin_session_token(admin) do
    {token, admin_token} = AdminToken.build_session_token(admin)
    repo().insert!(admin_token)
    token
  end

  @doc """
  Gets the admin with the given signed token.
  """
  @spec get_admin_by_session_token(String.t()) :: Admin.t()
  def get_admin_by_session_token(token) do
    {:ok, query} = AdminToken.verify_session_token_query(token)
    repo().one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_admin_session_token(String.t()) :: :ok
  def delete_admin_session_token(token) do
    repo().delete_all(AdminToken.by_token_and_context_query(token, "session"))
    :ok
  end

  defp repo, do: Application.fetch_env!(:blank, :repo)
end
