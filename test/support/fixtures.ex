defmodule Blank.Fixtures do
  @moduledoc false

  alias Blank.Accounts
  alias Blank.Accounts.{User, UserToken}

  # Creates a Blank user through the registration path, so the password is
  # hashed exactly as it is in production. Accepts `:name` and `:roles` in
  # addition to the registration attributes, with `:roles` defaulting to
  # `[:system_admin]`; `registration_changeset/2` casts neither field, so they
  # are applied with a plain change and written by the repo.
  @doc false
  def user_fixture(attrs \\ %{}) do
    defaults = %{
      email: "test_user_#{System.unique_integer([:positive])}@example.com",
      password: "Str0ng!Passw0rd"
    }

    attrs = Map.merge(defaults, Map.new(attrs))
    {name, attrs} = Map.pop(attrs, :name)
    {roles, attrs} = Map.pop(attrs, :roles, [:system_admin])

    {:ok, user} = Accounts.register_user(attrs)

    user
    |> Ecto.Changeset.change(%{roles: roles, name: name})
    |> TestApp.Repo.update!()
  end

  # Extra attributes are applied to the built struct, so a test can set
  # `:context`. The returned struct's `token` field is the token string.
  @doc false
  def user_token_fixture(%User{} = user, attrs \\ %{}) do
    {_token, user_token} = UserToken.build_session_token(user)

    user_token
    |> Map.merge(Map.new(attrs))
    |> TestApp.Repo.insert!()
  end
end
