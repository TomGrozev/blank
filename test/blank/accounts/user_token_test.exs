defmodule Blank.Accounts.UserTokenTest do
  use TestApp.DataCase

  alias Blank.Accounts.UserToken

  import Blank.Fixtures

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
      user_token = user_token_fixture(user)

      {:ok, query} = UserToken.verify_session_token_query(user_token.token)
      result = TestApp.Repo.one(query)

      assert result.id == user.id
    end
  end

  describe "by_token_and_context_query/2" do
    test "finds an inserted token by token and context" do
      user = user_fixture()
      inserted = user_token_fixture(user)

      query = UserToken.by_token_and_context_query(inserted.token, "session")
      result = TestApp.Repo.one(query)

      assert result.id == inserted.id
    end

    test "returns nil when token does not exist" do
      query = UserToken.by_token_and_context_query("nonexistent_token", "session")
      assert is_nil(TestApp.Repo.one(query))
    end

    test "returns nil when context does not match" do
      user = user_fixture()
      user_token = user_token_fixture(user)

      query = UserToken.by_token_and_context_query(user_token.token, "wrong_context")
      assert is_nil(TestApp.Repo.one(query))
    end
  end

  describe "by_user_and_contexts_query/2 with :all" do
    test "returns all tokens for the user" do
      user = user_fixture()
      user_token_fixture(user)
      user_token_fixture(user)

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
      user_token_fixture(user)

      # Insert a token with a different context
      user_token_fixture(user, %{context: "password_reset", last_activity_at: nil})

      query = UserToken.by_user_and_contexts_query(user, ["session"])
      results = TestApp.Repo.all(query)

      assert length(results) == 1
      assert Enum.all?(results, &(&1.context == "session"))
    end

    test "returns empty list when no tokens match the contexts" do
      user = user_fixture()

      user_token_fixture(user, %{context: "password_reset", last_activity_at: nil})

      query = UserToken.by_user_and_contexts_query(user, ["session"])
      results = TestApp.Repo.all(query)

      assert results == []
    end
  end
end
