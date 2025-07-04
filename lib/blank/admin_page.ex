defmodule Blank.AdminPage do
  @schema [
    schema: [
      type: :atom,
      required: true,
      doc: "the Ecto schema to use for the page"
    ],
    repo: [
      type: :atom,
      doc: "the Ecto Repo to use for the admin page"
    ],
    icon: [
      type: :string,
      doc: "the hero icon class to use for the sidebar"
    ],
    key: [
      type: :atom,
      doc: """
      the atom key for the schema. Only needed if you need to specify something
      other than the default.

      Defaults to the downcased version of the schema (e.g. for Post it would be
      :post).
      """
    ],
    name: [
      type: :string,
      doc: "name of the object for the page. Defaults to string of the key."
    ],
    plural_name: [
      type: :string,
      doc: """
      plural name of the object for the page. Defaults to the schema
      source (i.e. the table name).
      """
    ],
    index_fields: [
      type: {:list, :atom},
      doc: """
      list of fields to show on the index page.

      Defaults to all fields (including virtual fields and associations) minus 
      any foreign keys (i.e. for an association of posts, the post_id field 
      would excluded but not the posts field).
      """
    ],
    show_fields: [
      type: {:list, :atom},
      doc: """
      list of fields to show on the show page.

      Defaults to all index fields minus the `:inserted_at` and `:updated_at`
      fields.
      """
    ],
    edit_fields: [
      type: {:list, :atom},
      doc: """
      list of fields to show on the edit/new page.

      Defaults to all index fields minus the `:inserted_at` and `:updated_at`
      fields.
      """
    ],
    stats: [
      type: :non_empty_keyword_list,
      keys: [
        *: [
          type: :non_empty_keyword_list,
          keys: [
            name: [
              type: {:or, [:string, nil]},
              doc: """
              name of the stat.

              Defaults to a humanized name based on the key and the plural name. 
              E.g. for a key of `:total` and a plural name of `products` the
              generated name would be `Total proucts`.
              """
            ],
            display: [
              type: :atom,
              doc: "type of state, should be a stat module",
              default: Blank.Stats.Value
            ],
            formatter: [
              type: {:or, [{:fun, 2}, nil]},
              doc: """
              a function that formats the value

              Takes the admin page module and the value as options.

              A value of nil will not format the value and just displays the
              value.
              """,
              default: &Blank.Stats.named_value/2
            ]
          ]
        ]
      ],
      default: [
        total: [
          name: nil,
          display: Blank.Stats.Value,
          formatter: nil
        ]
      ]
    ]
  ]

  @moduledoc """
  Configures an admin page for some resource.

  An admin page is actually a group of three pages, an index page where all the
  records are listed, a show page where a specific item can be viewed, and an
  edit page where an item can be edited.

  Each admin page is configured by using this module. A seperate usage of this
  module is needed per resource. For example, you would need one for an admin
  page for posts and one for products.

  ## Basic Example

  An admin page to show posts could be created as follows.

      defmodule MyApp.Admin.PostsLive do
        alias MyApp.Products.Product

        use Blank.AdminPage,
          schema: Product,
          icon: "hero-archive-box",
          index_fields: [:title, :price]
      end

  ## Available options

  The available options to `use Blank.AdminPage` are:
  #{NimbleOptions.docs(@schema)}

  ## Custom Stats

  By default a total stat is included but you can add your own custom stats. You
  can also disable the total stat by settings the `:stats` option to `[]`.

  To add a custom stat you just add it to the `stats` option list. For example, 
  if you wanted a stat for the total number of products in stock you could configure it
  as below.

      [
        ...
        in_stock: [
          name: "Total in-stock",
        ]
        ...
      ]

  Here we have only configured the name of the stat and left all of the other
  options as the defaults. Make sure to include the total stat, otherwise it 
  won't be included. So for the above example we could include it by setting
  `:total` to `[]` (i.e. all defaults are used).

      [
        total: [],
        in_stock: [
          name: "Total in-stock",
        ]
        ...
      ]

  To configure how the stat queries data, you need to add a `c:stat_query/2`
  implementation. This function accepts two params, the first is the key for the
  stat and the second is the Ecto query used for the index page. The function
  then returns either a query that is run or a function that derives the value
  from the assigns on the page.

  See `c:stat_query/2` for more info.
  """

  import Ecto.Query, only: [from: 2, subquery: 1]

  @doc """
  Returns the config of the admin page
  """
  @callback config(key :: atom()) :: any()

  @doc """
  Returns the repo for the admin page
  """
  @callback repo() :: atom()

  @doc """
  Returns the stat query result

  ## Parameters

    * `key` - the key of the statistic that the query function returns
    * `query` - the ecto query used to list items

  ## Returns

  Can either return a query that is run to fetch the stat, or a value function
  that fetches the value from the assigns.

  ### Query stats

  If you want to perform an Ecto query you must return a tuple where the first
  element is `:query` and the second is the query to be run.  Note you probably
  will need to import `Ecto.Query` here.

  For the in stock example above, the function could be as follows.

      @impl Blank.AdminPage
      def stat_query(:in_stock, query) do
        {:query, from(i in query, where: i.stock > 0, select: count(i))}
      end

  ### Value stats

  If you would prefer to use some value that exists in the assigns
  on the page, you can return a tuple where the first element is `:value` and
  the second is a one arity function where the page's assigns is passed.

  The return of the function can be one of the following:

    * `{:ok, value}` - where `value` is the value to be used
    * `:loading` - if the value isn't available yet because the results list
      hasn't loaded yet
    * `:error` - if there was an error getting the value

  For the in stock example above, the function could be as follows.

      @impl Blank.AdminPage
      def stat_query(:in_stock, _query) do
        getter_fun = fn 
          %{in_stock_count: nil} = _assigns ->
            :loading

          %{in_stock_count: val} = _assigns ->
            {:ok, val}

          _ ->
            :error
        end
        {:value, getter_fun}
      end

  """
  @callback stat_query(key :: atom(), query :: Ecto.Query.t()) ::
              {:query, Ecto.Query.t()}
              | {:value, (Phoenix.LiveView.Socket.assigns() -> {:ok, any()} | :loading | :error)}

  @optional_callbacks stat_query: 2

  alias Phoenix.LiveView.AsyncResult
  alias Blank.Context
  use Blank.Web, :live_view

  defmacro __using__(opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    opts =
      opts
      |> validate_opts!(__CALLER__.module)
      |> Keyword.put_new_lazy(:key, fn -> get_key(opts[:schema]) end)

    default_fields = get_schema_fields(opts[:schema])

    opts =
      opts
      |> Keyword.put_new_lazy(:name, fn -> Atom.to_string(opts[:key]) end)
      |> Keyword.put_new(:plural_name, opts[:schema].__schema__(:source))
      |> Keyword.put_new(:index_fields, default_fields)
      |> then(fn kv ->
        default_edit_fields =
          Keyword.fetch!(kv, :index_fields)
          |> Enum.reject(&(&1 in [:inserted_at, :updated_at]))

        kv
        |> Keyword.put_new(:show_fields, default_edit_fields)
        |> Keyword.put_new(:edit_fields, default_edit_fields)
      end)

    quote do
      @behaviour Blank.AdminPage
      @after_compile unquote(__MODULE__)

      use Blank.Web, :live_view

      alias Blank.AdminPage

      @config_opts unquote(opts)

      @impl Phoenix.LiveView
      def mount(params, session, socket), do: AdminPage.mount(params, session, socket)

      @impl Phoenix.LiveView
      def handle_params(params, url, socket), do: AdminPage.handle_params(params, url, socket)

      @impl Phoenix.LiveView
      def handle_async(name, async_fun_result, socket),
        do: AdminPage.handle_async(name, async_fun_result, socket)

      @impl Phoenix.LiveView
      def handle_event(event, params, socket), do: AdminPage.handle_event(event, params, socket)

      @impl Phoenix.LiveView
      def handle_info(event, socket), do: AdminPage.handle_info(event, socket)

      @impl Phoenix.LiveView
      def render(assigns), do: AdminPage.render(assigns)

      @impl Blank.AdminPage
      def config(key), do: Keyword.fetch!(@config_opts, key)

      @impl Blank.AdminPage
      def repo do
        Keyword.get(
          @config_opts,
          :repo,
          Application.fetch_env!(:blank, :repo)
        )
      end
    end
  end

  def __after_compile__(%{module: module} = env, _) do
    with true <- Code.can_await_module_compilation?(),
         schema = module.config(:schema),
         false <- function_exported?(schema, :__schema__, 1) do
      IO.warn(
        "the schema passed must be an Ecto schema, got: #{inspect(schema)}",
        Macro.Env.stacktrace(env)
      )
    end

    :ok
  end

  defp get_schema_fields(schema) do
    foreign_keys =
      schema.__schema__(:associations)
      |> Stream.map(fn field -> schema.__schema__(:association, field) end)
      |> Stream.reject(&is_nil/1)
      |> Enum.map(& &1.owner_key)

    (schema.__schema__(:fields) ++
       schema.__schema__(:associations) ++ schema.__schema__(:virtual_fields))
    |> Enum.reject(&(&1 in foreign_keys))
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, env)

  defp expand_alias(other, _env), do: other

  defp validate_opts!(opts, caller) do
    case NimbleOptions.validate(opts, @schema) do
      {:ok, opts} ->
        opts

      {:error, err} ->
        raise Blank.Errors.InvalidConfigError.from_nimble(err,
                caller: caller,
                module: __MODULE__,
                usage: "use"
              )
    end
  end

  defp get_key(schema) do
    schema
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  embed_templates("admin_page/*")

  @doc false
  attr(:name, :string, required: true)
  attr(:item_name, :string, required: true)
  attr(:form, Phoenix.HTML.Form, required: true)
  attr(:fields, :list, required: true)
  attr(:form_btn, :string, required: true)
  attr(:schema, :atom, required: true)
  attr(:repo, :atom, required: true)
  attr(:time_zone, :string, required: true)
  def admin_edit(assigns)

  @doc false
  attr(:plural_name, :string, required: true)
  attr(:name, :string, required: true)
  attr(:active_link, :map, required: true)
  attr(:stats, :list, required: true)
  attr(:admin_page, :atom, required: true)
  attr(:filter_fields, :list, required: true)
  attr(:streams, :map, required: true)
  attr(:meta, Flop.Meta, required: true)
  attr(:primary_key, :atom, required: true)
  attr(:live_action, :atom, required: true)
  attr(:modal_fields, :list)
  attr(:fields, :list, required: true)
  attr(:schema, :atom, required: true)
  attr(:repo, :atom, required: true)
  attr(:time_zone, :string, required: true)
  def admin_index(assigns)

  @doc false
  attr(:name, :string, required: true)
  attr(:item_name, :string, required: true)
  attr(:active_link, :map, required: true)
  attr(:item, :map, required: true)
  attr(:fields, :list, required: true)
  attr(:primary_key, :atom, required: true)
  attr(:schema, :atom, required: true)
  attr(:time_zone, :string, required: true)
  def admin_show(assigns)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    admin_page = socket.view

    schema = admin_page.config(:schema)
    primary_key = Blank.Schema.primary_key(struct(schema))

    time_zone =
      with true <- connected?(socket),
           true <- Application.get_env(:blank, :use_local_timezone, false),
           %{"time_zone" => time_zone} <- get_connect_params(socket) do
        time_zone
      else
        _ ->
          "Etc/UTC"
      end

    {:ok,
     socket
     |> assign(:time_zone, time_zone)
     |> assign(:admin_page, admin_page)
     |> assign(:key, admin_page.config(:key))
     |> assign(:name, admin_page.config(:name))
     |> assign(:plural_name, admin_page.config(:plural_name))
     |> assign(:schema, admin_page.config(:schema))
     |> assign(:primary_key, primary_key)
     |> assign(:repo, admin_page.repo())
     |> assign(:meta, nil)
     |> stream(:items, [])}
  end

  @impl Phoenix.LiveView
  def render(%{live_action: :show} = assigns) do
    admin_show(assigns)
  end

  def render(%{live_action: action} = assigns) when action in [:index, :import, :export] do
    admin_index(assigns)
  end

  def render(%{live_action: action} = assigns) when action in [:new, :edit] do
    admin_edit(assigns)
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    admin_page = socket.view
    %{repo: repo, schema: schema} = socket.assigns

    fields =
      get_field_definitions(
        struct(schema),
        admin_page.config(:show_fields)
      )

    item = Context.get!(repo, schema, id, fields)

    socket
    |> assign(:item_name, Blank.Schema.name(item))
    |> assign(:item, item)
    |> assign(:fields, fields)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    admin_page = socket.view
    %{repo: repo, schema: schema} = socket.assigns

    fields =
      get_field_definitions(
        struct(schema),
        admin_page.config(:edit_fields)
      )

    item = Context.get!(repo, schema, id, fields)

    socket
    |> assign(:item_name, Blank.Schema.name(item))
    |> assign(:form_btn, {"Update", "Updating"})
    |> assign(:item, item)
    |> assign(:fields, fields)
    |> assign_new(:form, fn ->
      to_form(Context.change(item, :edit))
    end)
  end

  defp apply_action(socket, :new, _params) do
    admin_page = socket.view
    %{schema: schema} = socket.assigns

    fields =
      get_field_definitions(
        struct(schema),
        admin_page.config(:edit_fields)
      )

    item = struct(schema)

    socket
    |> assign(:item_name, "creation")
    |> assign(:form_btn, {"Create", "Creating"})
    |> assign(:item, item)
    |> assign(:fields, fields)
    |> assign_new(:form, fn ->
      to_form(Context.change(item, :new))
    end)
  end

  @search_field [
    search: [
      label: "Search...",
      op: :ilike
    ]
  ]
  defp apply_action(socket, action, params) when action in [:index, :import, :export] do
    admin_page = socket.view
    %{repo: repo, schema: schema} = socket.assigns

    fields = get_field_definitions(struct(schema), admin_page.config(:index_fields))

    modal_fields =
      case action do
        :index ->
          nil

        item when item in [:import, :export] ->
          get_field_definitions(struct(schema), admin_page.config(:edit_fields))
      end

    search =
      !Map.has_key?(params, "filters") or
        Map.get(params, "filters", []) |> Enum.any?(fn {_, v} -> v["field"] == "search" end)

    filter_fields =
      if search do
        @search_field
      else
        advanced_search(fields)
      end

    socket
    |> assign(:item, nil)
    |> assign(:fields, fields)
    |> assign(:filter_fields, filter_fields)
    |> assign(:modal_fields, modal_fields)
    |> assign_stats(repo, schema, fields, admin_page)
    |> assign(:items, AsyncResult.loading())
    |> start_async(:items, fn -> Context.paginate_schema(repo, schema, params, fields) end)
  end

  defp assign_stats(socket, repo, schema, fields, module) do
    query =
      Blank.Context.list_query(schema, fields)
      |> Ecto.Query.exclude(:preload)
      |> Ecto.Query.exclude(:group_by)
      |> Ecto.Query.exclude(:order_by)
      |> Ecto.Query.exclude(:select)

    {query_stats, stats} =
      module.config(:stats)
      |> Stream.map(fn {key, stat} ->
        res = stat_func(key, query, module)

        named_stat =
          Map.new(stat)
          |> Map.update!(:name, fn
            nil ->
              Phoenix.Naming.humanize(key) <> " " <> module.config(:plural_name)

            name ->
              name
          end)

        {key, named_stat, res}
      end)
      |> Enum.reduce({[], %{}}, fn
        {key, stat, {:query, _}} = val, {q, v} ->
          {[val | q], Map.put(v, key, Map.put(stat, :value, AsyncResult.loading()))}

        {key, stat, {:value, fun}}, {q, v} ->
          value = stat_value(fun, socket.assigns)
          new_stat = Map.merge(stat, %{value: value, value_fun: fun})

          {q, Map.put(v, key, new_stat)}
      end)

    socket
    |> assign(:stats, stats)
    |> maybe_async_query(query_stats, repo)
  end

  defp stat_func(:total, query, module) do
    try do
      module.stat_query(:total, query)
    rescue
      _e ->
        {:query, from(i in subquery(query), select: count(i))}
    end
  end

  defp stat_func(key, query, module), do: module.stat_query(key, query)

  defp stat_value(fun, assigns) do
    case fun.(assigns) do
      {:ok, val} -> AsyncResult.ok(val)
      :loading -> AsyncResult.loading()
      :error -> AsyncResult.failed(AsyncResult.loading(), :error)
    end
  end

  defp maybe_async_query(socket, [], _repo), do: socket

  defp maybe_async_query(socket, stats, repo) do
    multi =
      Enum.reduce(stats, Ecto.Multi.new(), fn {key, stat, {:query, query}}, multi ->
        display_module = stat_module(Map.fetch!(stat, :display))

        display_module.query(multi, {key, stat}, query)
      end)

    start_async(socket, :stats, fn -> repo.transaction(multi) end)
  end

  defp stat_module(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :render, 1) do
      mod
    else
      raise ArgumentError, """
      A stat module is required, got: #{inspect(mod)}.
      """
    end
  end

  defp reassign_stats(socket) do
    update(socket, :stats, fn stats ->
      Enum.map(stats, fn
        {k, %{value_fun: fun} = stat} ->
          {k, Map.put(stat, :value, stat_value(fun, socket.assigns))}

        stat ->
          stat
      end)
    end)
  end

  defp get_field_definitions(struct, fields) do
    Stream.map(fields, &{&1, Blank.Schema.get_field(struct, &1)})
    |> Enum.filter(&Map.get(elem(&1, 1), :viewable, true))
  end

  @impl Phoenix.LiveView
  def handle_async(:items, {:ok, {:ok, {items, meta}}}, socket) do
    {:noreply,
     socket
     |> assign(:meta, meta)
     |> assign(:items, AsyncResult.ok(:items))
     |> stream(:items, items, reset: true)
     |> reassign_stats()}
  end

  def handle_async(:items, _, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Failed to get items")
     |> push_navigate(to: socket.assigns.active_link.url)}
  end

  def handle_async(:stats, {:ok, {:ok, loaded}}, socket) do
    {:noreply,
     socket
     |> update(:stats, fn stats ->
       Enum.reduce(loaded, stats, fn {key, val}, acc ->
         put_in(acc, [key, :value], AsyncResult.ok(val))
       end)
     end)}
  end

  def handle_async(:stats, _, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       Enum.map(stats, fn {k, stat} ->
         {k, Map.update!(stat, :value, &AsyncResult.failed(&1, "failed to get stats"))}
       end)
     end)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"item_params" => params}, socket) do
    changeset =
      Context.change(
        socket.assigns.item,
        socket.assigns.live_action,
        decode(
          params,
          socket.assigns.fields
        )
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"item_params" => params}, socket) do
    params =
      decode(
        params,
        socket.assigns.fields
      )

    save_item(socket, socket.assigns.live_action, params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    item = Context.get!(socket.assigns.repo, socket.assigns.schema, id)
    {:ok, _} = Context.delete(socket.assigns.repo, socket.assigns.audit_context, item)

    {:noreply, stream_delete(socket, :items, item)}
  end

  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")

    query_url =
      Phoenix.VerifiedRoutes.unverified_path(
        socket,
        socket.router,
        socket.assigns.active_link.url,
        params
      )

    {:noreply, push_patch(socket, to: query_url)}
  end

  def handle_event("toggle-search", _params, socket) do
    filter_fields =
      if Keyword.has_key?(socket.assigns.filter_fields, :search) do
        advanced_search(socket.assigns.fields)
      else
        @search_field
      end

    {:noreply, assign(socket, :filter_fields, filter_fields)}
  end

  defp advanced_search(fields) do
    fields
    |> Stream.filter(fn {_, def} -> def.searchable end)
    |> Enum.map(fn
      {_name, %{filter_key: key, label: label}} ->
        {key,
         [
           label: label,
           op: :ilike_and
         ]}

      {name, %{label: label}} ->
        {name,
         [
           label: label,
           op: :ilike_and
         ]}
    end)
  end

  defp save_item(socket, :edit, params) do
    case Context.update(
           socket.assigns.repo,
           socket.assigns.audit_context,
           socket.assigns.item,
           params
         ) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{Phoenix.Naming.humanize(socket.assigns.name)} updated successfully"
         )
         |> push_patch(to: socket.assigns.active_link.url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Context.create(
           socket.assigns.repo,
           socket.assigns.audit_context,
           socket.assigns.item,
           params
         ) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{Phoenix.Naming.humanize(socket.assigns.name)} created successfully"
         )
         |> push_patch(to: socket.assigns.active_link.url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  @decode_fields [Blank.Fields.BelongsTo, Blank.Fields.Location]
  defp decode(value, fields) do
    fields
    |> Stream.filter(&(elem(&1, 1).module in @decode_fields))
    |> Enum.reduce(value, fn {key, _}, acc -> decode_selected_value(acc, Atom.to_string(key)) end)
  end

  defp decode_selected_value(map, key) do
    Map.update(map, key, nil, fn selected ->
      case selected do
        nil -> []
        "" -> nil
        selected when is_list(selected) -> Enum.map(selected, &decode_value/1)
        selected -> decode_value(selected)
      end
    end)
  end

  defp decode_value(value) when is_binary(value) do
    case Phoenix.json_library().decode(value) do
      {:ok, value} ->
        value

      _ ->
        value
    end
  end

  defp decode_value(value) when is_map(value), do: value
end
