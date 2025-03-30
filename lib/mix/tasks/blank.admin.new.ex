defmodule Mix.Tasks.Blank.Admin.New do
  @moduledoc """
  Creates a new admin in Blank
  """

  use Mix.Task
  import Mix.Ecto

  alias Blank.Accounts.Admin

  @aliases [
    r: :repo,
    e: :email,
    p: :password
  ]

  @switches [
    email: :string,
    password: :string,
    repo: [:keep, :string]
  ]

  @impl true
  def run(args) do
    repos = parse_repo(args)
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    with {:ok, email} <- Keyword.fetch(opts, :email),
         {:ok, password} <- Keyword.fetch(opts, :password) do
      repos
      |> Stream.map(&ensure_repo(&1, args))
      |> Enum.each(fn repo ->
        attrs = %{email: email, password: password}

        with {:ok, _} <- repo.__adapter__().ensure_all_started(repo.config(), :temporary),
             {:ok, _} <- repo.start_link(pool_size: 1) do
          %Admin{}
          |> Admin.registration_changeset(attrs, repo: repo)
          |> repo.insert()
        else
          {:error, %Ecto.Changeset{errors: errors}} ->
            Mix.Shell.IO.error("Failed to create admin, reason: #{inspect(errors)}")

          {:error, reason} ->
            Mix.Shell.IO.error("Failed to create admin, reason: #{inspect(reason)}")
        end
      end)
    end
  end
end
