defmodule Blank.Accounts.UserTokenTest do
  use TestApp.DataCase

  alias Blank.Accounts.{User, UserToken}

  @valid_email "user@example.com"
  @valid_password "Str0ng!Passw0rd"

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      %User{}
      |> User.registration_changeset(
        Map.merge(%{email: @valid_email, password: @valid_password}, attrs)
      )
      |> TestApp.Repo.insert()

    user
  end

  describe "build_session_token/1" do
    test "returns a {token_string, %UserToken{}} pair" do
      user = user_fixture()
      {token, user_token} = UserToken.build_session_token(user)

      assert is_binary(token)
      assert %UserToken{} = user_token
    end

    test "token string is a base64-encoded 32-byte random" do
      user = user_fixture()
      {token, _user_token} = UserToken.build_session_token(user)

      # Base64-encoded 32 bytes = 44 chars (with padding)
      decoded = Base.decode64!(token)
      assert byte_size(decoded) == 32
    end

    test "UserToken has context: 'session' and user_id: user.id" do
      user = user_fixture()
      {_token, user_token} = UserToken.build_session_token(user)

      assert user_token.context == "session"
      assert user_token.user_id == user.id
    end
  end

  describe "verify_session_token_query/1" do
    test "returns an Ecto.Query" do
      user = user_fixture()
      {token, _user_token_struct} = UserToken.build_session_token(user)

      assert {:ok, %Ecto.Query{}} = UserToken.verify_session_token_query(token)
    end

    test "query can be executed to retrieve the user" do
      user = user_fixture()
      {token, user_token_struct} = UserToken.build_session_token(user)
      TestApp.Repo.insert!(user_token_struct)

      {:ok, query} = UserToken.verify_session_token_query(token)
      result = TestApp.Repo.one(query)

      assert result.id == user.id
    end
  end

  describe "by_token_and_context_query/2" do
    test "finds an inserted token by token and context" do
      user = user_fixture()
      {token, user_token_struct} = UserToken.build_session_token(user)
      inserted = TestApp.Repo.insert!(user_token_struct)

      query = UserToken.by_token_and_context_query(token, "session")
      result = TestApp.Repo.one(query)

      assert result.id == inserted.id
    end

    test "returns nil when token does not exist" do
      query = UserToken.by_token_and_context_query("nonexistent_token", "session")
      assert is_nil(TestApp.Repo.one(query))
    end

    test "returns nil when context does not match" do
      user = user_fixture()
      {token, user_token_struct} = UserToken.build_session_token(user)
      TestApp.Repo.insert!(user_token_struct)

      query = UserToken.by_token_and_context_query(token, "wrong_context")
      assert is_nil(TestApp.Repo.one(query))
    end
  end

  describe "by_user_and_contexts_query/2 with :all" do
    test "returns all tokens for the user" do
      user = user_fixture()
      {_token1, struct1} = UserToken.build_session_token(user)
      {_token2, struct2} = UserToken.build_session_token(user)
      TestApp.Repo.insert!(struct1)
      TestApp.Repo.insert!(struct2)

      query = UserToken.by_user_and_contexts_query(user, :all)
      results = TestApp.Repo.all(query)

      assert length(results) == 2
    end

    test "returns empty list when user has no tokens" do
      user = user_fixture()

      query = UserToken.by_user_and_contexts_query(user, :all)
      results = TestApp.Repo.all(query)

      assert results == []
    end
  end

  describe "by_user_and_contexts_query/2 with context list" do
    test "returns only tokens with matching contexts" do
      user = user_fixture()

      # Insert a "session" token
      {_token1, struct1} = UserToken.build_session_token(user)
      TestApp.Repo.insert!(struct1)

      # Insert a token with a different context by constructing it manually
      other_token_struct = %UserToken{
        token: :crypto.strong_rand_bytes(32) |> Base.encode64(),
        context: "password_reset",
        user_id: user.id
      }

      TestApp.Repo.insert!(other_token_struct)

      query = UserToken.by_user_and_contexts_query(user, ["session"])
      results = TestApp.Repo.all(query)

      assert length(results) == 1
      assert Enum.all?(results, &(&1.context == "session"))
    end

    test "returns empty list when no tokens match the contexts" do
      user = user_fixture()

      other_token_struct = %UserToken{
        token: :crypto.strong_rand_bytes(32) |> Base.encode64(),
        context: "password_reset",
        user_id: user.id
      }

      TestApp.Repo.insert!(other_token_struct)

      query = UserToken.by_user_and_contexts_query(user, ["session"])
      results = TestApp.Repo.all(query)

      assert results == []
    end
  end
end
