defmodule Blank.Config do
  @moduledoc """
  Configuration management for Blank.

  `Blank.Config` is the single owner of Blank's config reads: nothing else reads
  the `:blank, :authorization` key or the `:blank, :repo` key. It reads config
  through `Application` and caches only the allowed-role set, through
  `:persistent_term`.

  The allowed-role set is the only cached value. `policy_module/0` and
  `role_mapper_config/0` read config at call time, so a config change made after
  boot is visible on the next call.
  """

  @allowed_roles_key :blank_allowed_roles

  @built_in_roles MapSet.new([:system_admin, :member])

  @doc """
  Returns the cached allowed roles set.

  If not cached (e.g., called before boot), computes and caches it.
  """
  @spec allowed_roles() :: MapSet.t(atom())
  def allowed_roles do
    case :persistent_term.get(@allowed_roles_key, :not_set) do
      :not_set -> compute_and_cache_allowed_roles()
      roles -> roles
    end
  end

  @doc """
  Computes the allowed roles from config and caches them.
  Called at app boot time.
  """
  @spec compute_and_cache_allowed_roles() :: MapSet.t(atom())
  def compute_and_cache_allowed_roles do
    roles = MapSet.union(@built_in_roles, MapSet.new(configured_roles()))
    :persistent_term.put(@allowed_roles_key, roles)
    roles
  end

  @doc """
  Returns the built-in roles that are always present regardless of config.
  """
  @spec built_in_roles() :: MapSet.t(atom())
  def built_in_roles, do: @built_in_roles

  @doc """
  Returns the consumer-configured roles from `config :blank, :authorization, roles: [...]`.
  """
  @spec configured_roles() :: [atom()]
  def configured_roles do
    Keyword.get(authorization_config(), :roles, [])
  end

  @doc """
  Returns the configured policy module, or `Blank.Authorization.DefaultPolicy`
  if none is configured.

  Reads from `config :blank, :authorization, policy_module: MyApp.Policy`.
  """
  @spec policy_module() :: module()
  def policy_module do
    Keyword.get(authorization_config(), :policy_module, Blank.Authorization.DefaultPolicy)
  end

  @doc """
  Returns the configured role mapper as `{module, opts}`, or `nil` if none is configured.

  Reads from `config :blank, :authorization, role_mapper: ...`.

  Supports two config shapes:
    * `{Module, opts}` — module with explicit options
    * `Module` — plain module shorthand (no-opts, equivalent to `{Module, []}`)

  ## Examples

      # config :blank, :authorization, role_mapper: {MyMapper, [key: :value]}
      iex> role_mapper_config()
      {MyMapper, [key: :value]}

      # config :blank, :authorization, role_mapper: MyMapper
      iex> role_mapper_config()
      {MyMapper, []}

      # no role_mapper configured
      iex> role_mapper_config()
      nil
  """
  @spec role_mapper_config() :: {module(), keyword()} | nil
  def role_mapper_config do
    case Keyword.get(authorization_config(), :role_mapper) do
      nil ->
        nil

      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}

      module when is_atom(module) ->
        {module, []}
    end
  end

  @doc """
  Returns the configured Ecto repo from `config :blank, :repo`.

  Reads at call time, so a config change made after boot is visible on the next
  call. Raises `ArgumentError` when the key is unset.
  """
  @spec repo() :: Ecto.Repo.t()
  def repo, do: Application.fetch_env!(:blank, :repo)

  # Sole direct read of the `:blank, :authorization` key. It sits here so the
  # rest of Blank reaches that key only through this module. Reading at call time
  # (never caching) is what makes a post-boot config change visible on the next
  # call, per CODING_STANDARDS.md rule 11.
  defp authorization_config do
    Application.get_env(:blank, :authorization, [])
  end
end
