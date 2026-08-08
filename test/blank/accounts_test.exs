defmodule Blank.AccountsTest do
  use TestApp.DataCase

  alias Blank.Accounts
  alias Blank.Accounts.{User, UserToken}

  @valid_email "user@example.com"
  @valid_password "Str0ng!Passw0rd"

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      Accounts.register_user(Map.merge(%{email: @valid_email, password: @valid_password}, attrs))

    user
  end

  # ── list_users/0 ──

  describe "list_users/0" do
    test "returns all users" do
      user1 = user_fixture(%{email: "one@example.com"})
      user2 = user_fixture(%{email: "two@example.com"})

      users = Accounts.list_users()
      ids = Enum.map(users, & &1.id)

      assert user1.id in ids
      assert user2.id in ids
    end

    test "returns empty list when no users exist" do
      assert Accounts.list_users() == []
    end
  end

  # ── get_user_by_email/1 ──

  describe "get_user_by_email/1" do
    test "returns the user with the given email" do
      user = user_fixture()
      result = Accounts.get_user_by_email(@valid_email)

      assert result.id == user.id
    end

    test "returns nil for unknown email" do
      assert is_nil(Accounts.get_user_by_email("unknown@example.com"))
    end
  end

  # ── get_user_by_email_and_password/2 ──

  describe "get_user_by_email_and_password/2" do
    test "returns the user with valid credentials" do
      user = user_fixture()
      result = Accounts.get_user_by_email_and_password(@valid_email, @valid_password)

      assert result.id == user.id
    end

    test "returns nil with invalid email" do
      assert is_nil(Accounts.get_user_by_email_and_password("noone@example.com", @valid_password))
    end

    test "returns nil with invalid password" do
      user_fixture()
      assert is_nil(Accounts.get_user_by_email_and_password(@valid_email, "WRONG_password123!"))
    end
  end

  # ── get_user!/1 ──

  describe "get_user!/1" do
    test "returns the user" do
      user = user_fixture()
      result = Accounts.get_user!(user.id)

      assert result.id == user.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(0)
      end
    end
  end

  # ── register_user/2 ──

  describe "register_user/2" do
    test "creates a new user with valid attributes" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{email: "new@example.com", password: @valid_password})

      assert user.email == "new@example.com"
    end

    test "returns error changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} =
               Accounts.register_user(%{email: "bad"})
    end
  end

  # ── change_user_registration/2 ──

  describe "change_user_registration/2" do
    test "returns an Ecto.Changeset" do
      user = %User{}
      changeset = Accounts.change_user_registration(user)

      assert %Ecto.Changeset{} = changeset
    end
  end

  # ── delete_user/1 ──

  describe "delete_user/1" do
    test "removes the user from the database" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)

      assert is_nil(TestApp.Repo.get(User, user.id))
    end
  end

  # ── change_user_password/2 ──

  describe "change_user_password/2" do
    test "returns an Ecto.Changeset" do
      user = user_fixture()
      changeset = Accounts.change_user_password(user)

      assert %Ecto.Changeset{} = changeset
    end
  end

  # ── update_user_password/3 ──

  describe "update_user_password/3" do
    test "updates the password and deletes all tokens" do
      user = user_fixture()

      # Create a session token so we can verify it's deleted
      token = Accounts.generate_user_session_token(user)
      assert TestApp.Repo.one(from(t in UserToken, where: t.token == ^token))

      new_password = "N3w!Password123"

      assert {:ok, %User{}} =
               Accounts.update_user_password(user, @valid_password, %{password: new_password})

      # Token should be gone
      assert is_nil(TestApp.Repo.one(from(t in UserToken, where: t.token == ^token)))
    end

    test "returns error changeset when current password is wrong" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_user_password(user, "WRONG_password123!", %{
                 password: "N3w!Password123"
               })
    end
  end

  # ── generate_user_session_token/1 ──

  describe "generate_user_session_token/1" do
    test "creates a session token in the database" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      assert is_binary(token)

      db_token = TestApp.Repo.one(from(t in UserToken, where: t.token == ^token))
      assert db_token
      assert db_token.user_id == user.id
      assert db_token.context == "session"
    end
  end

  # ── get_user_by_session_token/1 ──

  describe "get_user_by_session_token/1" do
    test "returns the user for a valid token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      result = Accounts.get_user_by_session_token(token)
      assert result.id == user.id
    end

    test "returns nil for an invalid token" do
      assert is_nil(Accounts.get_user_by_session_token("invalid_token"))
    end
  end

  # ── delete_user_session_token/1 ──

  describe "delete_user_session_token/1" do
    test "removes the specific token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      assert :ok = Accounts.delete_user_session_token(token)

      assert is_nil(TestApp.Repo.one(from(t in UserToken, where: t.token == ^token)))
    end
  end
end
