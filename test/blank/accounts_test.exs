defmodule Blank.AccountsTest do
  use TestApp.DataCase

  alias Blank.Accounts
  alias Blank.Accounts.{Admin, AdminToken}

  @valid_email "admin@example.com"
  @valid_password "Str0ng!Passw0rd"

  defp admin_fixture(attrs \\ %{}) do
    {:ok, admin} =
      Accounts.register_admin(Map.merge(%{email: @valid_email, password: @valid_password}, attrs))

    admin
  end

  # ── list_admins/0 ──

  describe "list_admins/0" do
    test "returns all admins" do
      admin1 = admin_fixture(%{email: "one@example.com"})
      admin2 = admin_fixture(%{email: "two@example.com"})

      admins = Accounts.list_admins()
      ids = Enum.map(admins, & &1.id)

      assert admin1.id in ids
      assert admin2.id in ids
    end

    test "returns empty list when no admins exist" do
      assert Accounts.list_admins() == []
    end
  end

  # ── get_admin_by_email/1 ──

  describe "get_admin_by_email/1" do
    test "returns the admin with the given email" do
      admin = admin_fixture()
      result = Accounts.get_admin_by_email(@valid_email)

      assert result.id == admin.id
    end

    test "returns nil for unknown email" do
      assert is_nil(Accounts.get_admin_by_email("unknown@example.com"))
    end
  end

  # ── get_admin_by_email_and_password/2 ──

  describe "get_admin_by_email_and_password/2" do
    test "returns the admin with valid credentials" do
      admin = admin_fixture()
      result = Accounts.get_admin_by_email_and_password(@valid_email, @valid_password)

      assert result.id == admin.id
    end

    test "returns nil with invalid email" do
      assert is_nil(
               Accounts.get_admin_by_email_and_password("noone@example.com", @valid_password)
             )
    end

    test "returns nil with invalid password" do
      admin_fixture()
      assert is_nil(Accounts.get_admin_by_email_and_password(@valid_email, "WRONG_password123!"))
    end
  end

  # ── get_admin!/1 ──

  describe "get_admin!/1" do
    test "returns the admin" do
      admin = admin_fixture()
      result = Accounts.get_admin!(admin.id)

      assert result.id == admin.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_admin!(0)
      end
    end
  end

  # ── register_admin/2 ──

  describe "register_admin/2" do
    test "creates a new admin with valid attributes" do
      assert {:ok, %Admin{} = admin} =
               Accounts.register_admin(%{email: "new@example.com", password: @valid_password})

      assert admin.email == "new@example.com"
    end

    test "returns error changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} =
               Accounts.register_admin(%{email: "bad"})
    end
  end

  # ── change_admin_registration/2 ──

  describe "change_admin_registration/2" do
    test "returns an Ecto.Changeset" do
      admin = %Admin{}
      changeset = Accounts.change_admin_registration(admin)

      assert %Ecto.Changeset{} = changeset
    end
  end

  # ── delete_admin/1 ──

  describe "delete_admin/1" do
    test "removes the admin from the database" do
      admin = admin_fixture()
      assert {:ok, %Admin{}} = Accounts.delete_admin(admin)

      assert is_nil(TestApp.Repo.get(Admin, admin.id))
    end
  end

  # ── change_admin_password/2 ──

  describe "change_admin_password/2" do
    test "returns an Ecto.Changeset" do
      admin = admin_fixture()
      changeset = Accounts.change_admin_password(admin)

      assert %Ecto.Changeset{} = changeset
    end
  end

  # ── update_admin_password/3 ──

  describe "update_admin_password/3" do
    test "updates the password and deletes all tokens" do
      admin = admin_fixture()

      # Create a session token so we can verify it's deleted
      token = Accounts.generate_admin_session_token(admin)
      assert TestApp.Repo.one(from(t in AdminToken, where: t.token == ^token))

      new_password = "N3w!Password123"

      assert {:ok, %Admin{}} =
               Accounts.update_admin_password(admin, @valid_password, %{password: new_password})

      # Token should be gone
      assert is_nil(TestApp.Repo.one(from(t in AdminToken, where: t.token == ^token)))
    end

    test "returns error changeset when current password is wrong" do
      admin = admin_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_admin_password(admin, "WRONG_password123!", %{
                 password: "N3w!Password123"
               })
    end
  end

  # ── generate_admin_session_token/1 ──

  describe "generate_admin_session_token/1" do
    test "creates a session token in the database" do
      admin = admin_fixture()
      token = Accounts.generate_admin_session_token(admin)

      assert is_binary(token)

      db_token = TestApp.Repo.one(from(t in AdminToken, where: t.token == ^token))
      assert db_token
      assert db_token.admin_id == admin.id
      assert db_token.context == "session"
    end
  end

  # ── get_admin_by_session_token/1 ──

  describe "get_admin_by_session_token/1" do
    test "returns the admin for a valid token" do
      admin = admin_fixture()
      token = Accounts.generate_admin_session_token(admin)

      result = Accounts.get_admin_by_session_token(token)
      assert result.id == admin.id
    end

    test "returns nil for an invalid token" do
      assert is_nil(Accounts.get_admin_by_session_token("invalid_token"))
    end
  end

  # ── delete_admin_session_token/1 ──

  describe "delete_admin_session_token/1" do
    test "removes the specific token" do
      admin = admin_fixture()
      token = Accounts.generate_admin_session_token(admin)

      assert :ok = Accounts.delete_admin_session_token(token)

      assert is_nil(TestApp.Repo.one(from(t in AdminToken, where: t.token == ^token)))
    end
  end
end
