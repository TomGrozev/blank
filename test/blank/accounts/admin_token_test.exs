defmodule Blank.Accounts.AdminTokenTest do
  use TestApp.DataCase

  alias Blank.Accounts.{Admin, AdminToken}

  @valid_email "admin@example.com"
  @valid_password "Str0ng!Passw0rd"

  defp admin_fixture(attrs \\ %{}) do
    {:ok, admin} =
      %Admin{}
      |> Admin.registration_changeset(
        Map.merge(%{email: @valid_email, password: @valid_password}, attrs)
      )
      |> TestApp.Repo.insert()

    admin
  end

  describe "build_session_token/1" do
    test "returns a {token_string, %AdminToken{}} pair" do
      admin = admin_fixture()
      {token, admin_token} = AdminToken.build_session_token(admin)

      assert is_binary(token)
      assert %AdminToken{} = admin_token
    end

    test "token string is a base64-encoded 32-byte random" do
      admin = admin_fixture()
      {token, _admin_token} = AdminToken.build_session_token(admin)

      # Base64-encoded 32 bytes = 44 chars (with padding)
      decoded = Base.decode64!(token)
      assert byte_size(decoded) == 32
    end

    test "AdminToken has context: 'session' and admin_id: admin.id" do
      admin = admin_fixture()
      {_token, admin_token} = AdminToken.build_session_token(admin)

      assert admin_token.context == "session"
      assert admin_token.admin_id == admin.id
    end
  end

  describe "verify_session_token_query/1" do
    test "returns an Ecto.Query" do
      admin = admin_fixture()
      {token, _admin_token_struct} = AdminToken.build_session_token(admin)

      assert {:ok, %Ecto.Query{}} = AdminToken.verify_session_token_query(token)
    end

    test "query can be executed to retrieve the admin" do
      admin = admin_fixture()
      {token, admin_token_struct} = AdminToken.build_session_token(admin)
      TestApp.Repo.insert!(admin_token_struct)

      {:ok, query} = AdminToken.verify_session_token_query(token)
      result = TestApp.Repo.one(query)

      assert result.id == admin.id
    end
  end

  describe "by_token_and_context_query/2" do
    test "finds an inserted token by token and context" do
      admin = admin_fixture()
      {token, admin_token_struct} = AdminToken.build_session_token(admin)
      inserted = TestApp.Repo.insert!(admin_token_struct)

      query = AdminToken.by_token_and_context_query(token, "session")
      result = TestApp.Repo.one(query)

      assert result.id == inserted.id
    end

    test "returns nil when token does not exist" do
      query = AdminToken.by_token_and_context_query("nonexistent_token", "session")
      assert is_nil(TestApp.Repo.one(query))
    end

    test "returns nil when context does not match" do
      admin = admin_fixture()
      {token, admin_token_struct} = AdminToken.build_session_token(admin)
      TestApp.Repo.insert!(admin_token_struct)

      query = AdminToken.by_token_and_context_query(token, "wrong_context")
      assert is_nil(TestApp.Repo.one(query))
    end
  end

  describe "by_admin_and_contexts_query/2 with :all" do
    test "returns all tokens for the admin" do
      admin = admin_fixture()
      {_token1, struct1} = AdminToken.build_session_token(admin)
      {_token2, struct2} = AdminToken.build_session_token(admin)
      TestApp.Repo.insert!(struct1)
      TestApp.Repo.insert!(struct2)

      query = AdminToken.by_admin_and_contexts_query(admin, :all)
      results = TestApp.Repo.all(query)

      assert length(results) == 2
    end

    test "returns empty list when admin has no tokens" do
      admin = admin_fixture()

      query = AdminToken.by_admin_and_contexts_query(admin, :all)
      results = TestApp.Repo.all(query)

      assert results == []
    end
  end

  describe "by_admin_and_contexts_query/2 with context list" do
    test "returns only tokens with matching contexts" do
      admin = admin_fixture()

      # Insert a "session" token
      {_token1, struct1} = AdminToken.build_session_token(admin)
      TestApp.Repo.insert!(struct1)

      # Insert a token with a different context by constructing it manually
      other_token_struct = %AdminToken{
        token: :crypto.strong_rand_bytes(32) |> Base.encode64(),
        context: "password_reset",
        admin_id: admin.id
      }

      TestApp.Repo.insert!(other_token_struct)

      query = AdminToken.by_admin_and_contexts_query(admin, ["session"])
      results = TestApp.Repo.all(query)

      assert length(results) == 1
      assert Enum.all?(results, &(&1.context == "session"))
    end

    test "returns empty list when no tokens match the contexts" do
      admin = admin_fixture()

      other_token_struct = %AdminToken{
        token: :crypto.strong_rand_bytes(32) |> Base.encode64(),
        context: "password_reset",
        admin_id: admin.id
      }

      TestApp.Repo.insert!(other_token_struct)

      query = AdminToken.by_admin_and_contexts_query(admin, ["session"])
      results = TestApp.Repo.all(query)

      assert results == []
    end
  end
end
