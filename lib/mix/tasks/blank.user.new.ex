defmodule Mix.Tasks.Blank.User.New do
  @moduledoc """
  Creates a new local user in Blank.

  This is a break-glass path for creating local User records directly in the
  database when the IdP is unreachable.

  For example:

      mix blank.user.new -e user@example.com -p "Password123!" -n "User Name"

  Accepts the following options:

    * `repo` - the repo to use, defaults to fetching from the app environment
    * `email` - the user's email (required)
    * `password` - the user's password (required)
    * `name` - the user's display name (optional)
    * `roles` - comma-separated list of roles (optional)
  """

  use Mix.Task
  import Mix.Ecto

  alias Blank.Accounts.User

  @aliases [
    r: :repo,
    e: :email,
    p: :password,
    n: :name
  ]

  @switches [
    email: :string,
    password: :string,
    name: :string,
    roles: :string,
    repo: [:keep, :string]
  ]

  @impl true
  def run(args) do
    repos = parse_repo(args)
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    with {:ok, email} <- Keyword.fetch(opts, :email),
         {:ok, password} <- Keyword.fetch(opts, :password) do
      {:ok, _} = Application.ensure_all_started(:blank)

      name = Keyword.get(opts, :name)
      roles = parse_roles(Keyword.get(opts, :roles))

      repos
      |> Stream.map(&ensure_repo(&1, args))
      |> Enum.each(fn repo ->
        changeset =
          %User{}
          |> User.registration_changeset(%{email: email, password: password}, repo: repo)
          |> Ecto.Changeset.put_change(:name, name)
          |> Ecto.Changeset.cast(%{roles: roles}, [:roles])

        with {:ok, _} <- repo.__adapter__().ensure_all_started(repo.config(), :temporary),
             {:ok, _} <- ensure_repo_started(repo),
             {:ok, user} <- repo.insert(changeset) do
          string_roles = Enum.map(user.roles, &Atom.to_string/1)

          Blank.Audit.log!(
            Blank.Audit.AuditLog.system(),
            "accounts.user_created",
            %{email: email, roles: string_roles}
          )

          Mix.shell().info("User #{email} created successfully")
        else
          {:error, %Ecto.Changeset{errors: errors}} ->
            Mix.Shell.IO.error("Failed to create user, reason: #{inspect(errors)}")

          {:error, reason} ->
            Mix.Shell.IO.error("Failed to create user, reason: #{inspect(reason)}")
        end
      end)
    end
  end

  defp ensure_repo_started(repo) do
    case repo.start_link(pool_size: 1) do
      {:ok, _} = ok -> ok
      {:error, {:already_started, _}} -> {:ok, repo}
    end
  end

  defp parse_roles(nil), do: []

  defp parse_roles(roles_string) do
    roles_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
