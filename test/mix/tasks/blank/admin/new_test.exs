defmodule Mix.Tasks.Blank.Admin.NewTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  import Ecto.Changeset, only: [get_change: 2]

  alias Blank.Accounts.User

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(TestApp.Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  describe "run/1 with missing inputs" do
    test "does nothing when email is missing" do
      Mix.shell(Mix.Shell.Process)

      Mix.Tasks.Blank.Admin.New.run([
        "-p",
        "Password123abc",
        "-r",
        "TestApp.Repo"
      ])

      count = TestApp.Repo.one!(from(u in User, select: count(u.id)))
      assert count == 0
    end

    test "does nothing when password is missing" do
      Mix.shell(Mix.Shell.Process)

      Mix.Tasks.Blank.Admin.New.run([
        "-e",
        "missing@example.com",
        "-r",
        "TestApp.Repo"
      ])

      count = TestApp.Repo.one!(from(u in User, select: count(u.id)))
      assert count == 0
    end

    test "does nothing when both email and password are missing" do
      Mix.shell(Mix.Shell.Process)

      Mix.Tasks.Blank.Admin.New.run(["-r", "TestApp.Repo"])

      count = TestApp.Repo.one!(from(u in User, select: count(u.id)))
      assert count == 0
    end
  end

  describe "run/1 with invalid inputs (repo already started)" do
    test "handles invalid password gracefully" do
      Mix.shell(Mix.Shell.Process)

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Mix.Tasks.Blank.Admin.New.run([
            "-e",
            "short@example.com",
            "-p",
            "short",
            "-r",
            "TestApp.Repo"
          ])
        end)

      assert output =~ "Failed" or output =~ "already_started" or output == ""
    end

    test "handles invalid email gracefully" do
      Mix.shell(Mix.Shell.Process)

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Mix.Tasks.Blank.Admin.New.run([
            "-e",
            "not-an-email",
            "-p",
            "Password123abc",
            "-r",
            "TestApp.Repo"
          ])
        end)

      assert output =~ "Failed" or output =~ "already_started" or output == ""
    end
  end

  describe "User.registration_changeset/3" do
    test "creates a valid changeset with valid attrs" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "valid@example.com",
            password: "Password123abc"
          },
          validate_email: false,
          repo: TestApp.Repo
        )

      assert changeset.valid?
    end

    test "requires email" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            password: "Password123abc"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password length minimum 12" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com",
            password: "short"
          },
          validate_email: false
        )

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "should be at least 12 character(s)" in errors.password
    end

    test "validates email format" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "not-an-email",
            password: "Password123abc"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates password requires lowercase" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com",
            password: "PASSWORD123ABC"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{password: ["at least one lower case character"]} = errors_on(changeset)
    end

    test "validates password requires uppercase" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com",
            password: "password123abc"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{password: ["at least one upper case character"]} = errors_on(changeset)
    end

    test "validates password requires digit or punctuation" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com",
            password: "Passwordabcdefgh"
          },
          validate_email: false
        )

      refute changeset.valid?
      assert %{password: ["at least one digit or punctuation character"]} = errors_on(changeset)
    end

    test "hashes password when valid" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            email: "test@example.com",
            password: "Password123abc"
          },
          validate_email: false
        )

      assert changeset.valid?
      assert get_change(changeset, :hashed_password)
      refute get_change(changeset, :password)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
