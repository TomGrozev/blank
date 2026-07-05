defmodule Blank.Accounts.UserTest do
  use TestApp.DataCase

  alias Blank.Accounts.User

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

  # ── registration_changeset/2,3 ──

  describe "registration_changeset/2,3" do
    test "valid email + valid password produces a valid changeset" do
      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: @valid_password})

      assert changeset.valid?
    end

    test "missing email produces an error" do
      changeset = User.registration_changeset(%User{}, %{password: @valid_password})
      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "email too long (>160 chars) produces an error" do
      long_email = String.duplicate("a", 161) <> "@example.com"

      changeset =
        User.registration_changeset(%User{}, %{email: long_email, password: @valid_password})

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "invalid email format (no @ sign) produces an error" do
      changeset =
        User.registration_changeset(%User{}, %{email: "notanemail", password: @valid_password})

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "password too short (<12 chars) produces an error" do
      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: "Short1!"})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password too long (>72 chars) produces an error" do
      long_password = String.duplicate("A", 73) <> "1a!"

      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: long_password})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing lowercase produces an error" do
      changeset =
        User.registration_changeset(%User{}, %{
          email: @valid_email,
          password: "NOLOWERCASE1234!"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing uppercase produces an error" do
      changeset =
        User.registration_changeset(%User{}, %{
          email: @valid_email,
          password: "nouppercase1234!"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing digit-or-punct produces an error" do
      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: "NoDigitsHereABC"})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "duplicate email produces a unique constraint error" do
      _user = user_fixture()

      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: @valid_password})

      assert {:error, changeset} = TestApp.Repo.insert(changeset)
      assert %{email: _} = errors_on(changeset)
    end

    test "hashed_password is set when hash_password: true (default)" do
      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: @valid_password})

      assert Ecto.Changeset.get_change(changeset, :hashed_password)
    end

    test "hashed_password is not set when hash_password: false" do
      changeset =
        User.registration_changeset(%User{}, %{email: @valid_email, password: @valid_password},
          hash_password: false
        )

      refute Ecto.Changeset.get_change(changeset, :hashed_password)
    end
  end

  # ── password_changeset/2,3 ──

  describe "password_changeset/2,3" do
    test "matching password and password_confirmation is valid" do
      user = user_fixture()

      changeset =
        User.password_changeset(user, %{
          password: "N3w!Password123",
          password_confirmation: "N3w!Password123"
        })

      assert changeset.valid?
    end

    test "non-matching password and password_confirmation produces an error" do
      user = user_fixture()

      changeset =
        User.password_changeset(user, %{
          password: "N3w!Password123",
          password_confirmation: "D1ff3rent!Pass"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password_confirmation]
    end
  end

  # ── valid_password?/2 ──

  describe "valid_password?/2" do
    test "returns true with the correct password" do
      user = user_fixture()
      assert User.valid_password?(user, @valid_password)
    end

    test "returns false with the wrong password" do
      user = user_fixture()
      refute User.valid_password?(user, "WRONG_password123!")
    end
  end

  # ── validate_current_password/2 ──

  describe "validate_current_password/2" do
    test "returns changeset without error when password is correct" do
      user = user_fixture()
      changeset = Ecto.Changeset.change(user)
      result = User.validate_current_password(changeset, @valid_password)
      refute result.errors[:current_password]
    end

    test "adds error to changeset when password is wrong" do
      user = user_fixture()
      changeset = Ecto.Changeset.change(user)
      result = User.validate_current_password(changeset, "WRONG_password123!")
      assert {"is not valid", _} = result.errors[:current_password]
    end
  end
end
