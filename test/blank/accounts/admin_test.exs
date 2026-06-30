defmodule Blank.Accounts.AdminTest do
  use TestApp.DataCase

  alias Blank.Accounts.Admin

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

  # ── registration_changeset/2,3 ──

  describe "registration_changeset/2,3" do
    test "valid email + valid password produces a valid changeset" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: @valid_password})

      assert changeset.valid?
    end

    test "missing email produces an error" do
      changeset = Admin.registration_changeset(%Admin{}, %{password: @valid_password})
      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "email too long (>160 chars) produces an error" do
      long_email = String.duplicate("a", 161) <> "@example.com"

      changeset =
        Admin.registration_changeset(%Admin{}, %{email: long_email, password: @valid_password})

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "invalid email format (no @ sign) produces an error" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: "notanemail", password: @valid_password})

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "password too short (<12 chars) produces an error" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: "Short1!"})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password too long (>72 chars) produces an error" do
      long_password = String.duplicate("A", 73) <> "1a!"

      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: long_password})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing lowercase produces an error" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{
          email: @valid_email,
          password: "NOLOWERCASE1234!"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing uppercase produces an error" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{
          email: @valid_email,
          password: "nouppercase1234!"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "password missing digit-or-punct produces an error" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: "NoDigitsHereABC"})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end

    test "duplicate email produces a unique constraint error" do
      _admin = admin_fixture()

      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: @valid_password})

      assert {:error, changeset} = TestApp.Repo.insert(changeset)
      assert %{email: _} = errors_on(changeset)
    end

    test "hashed_password is set when hash_password: true (default)" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: @valid_password})

      assert Ecto.Changeset.get_change(changeset, :hashed_password)
    end

    test "hashed_password is not set when hash_password: false" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{email: @valid_email, password: @valid_password},
          hash_password: false
        )

      refute Ecto.Changeset.get_change(changeset, :hashed_password)
    end
  end

  # ── password_changeset/2,3 ──

  describe "password_changeset/2,3" do
    test "matching password and password_confirmation is valid" do
      admin = admin_fixture()

      changeset =
        Admin.password_changeset(admin, %{
          password: "N3w!Password123",
          password_confirmation: "N3w!Password123"
        })

      assert changeset.valid?
    end

    test "non-matching password and password_confirmation produces an error" do
      admin = admin_fixture()

      changeset =
        Admin.password_changeset(admin, %{
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
      admin = admin_fixture()
      assert Admin.valid_password?(admin, @valid_password)
    end

    test "returns false with the wrong password" do
      admin = admin_fixture()
      refute Admin.valid_password?(admin, "WRONG_password123!")
    end
  end

  # ── validate_current_password/2 ──

  describe "validate_current_password/2" do
    test "returns changeset without error when password is correct" do
      admin = admin_fixture()
      changeset = Ecto.Changeset.change(admin)
      result = Admin.validate_current_password(changeset, @valid_password)
      refute result.errors[:current_password]
    end

    test "adds error to changeset when password is wrong" do
      admin = admin_fixture()
      changeset = Ecto.Changeset.change(admin)
      result = Admin.validate_current_password(changeset, "WRONG_password123!")
      assert {"is not valid", _} = result.errors[:current_password]
    end
  end
end
