defmodule Blank.AdminPage do
  @moduledoc """
  This represents an administable resource.
  """

  @callback config(key :: atom()) :: any()
  @callback repo() :: atom()

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
      doc: "the atom key for the schema"
    ],
    name: [
      type: :string,
      doc: "name of the object for the page"
    ],
    plural_name: [
      type: :string,
      doc: "plural name of the object for the page"
    ],
    index_fields: [
      type: {:list, :atom},
      doc: "list of fields to show on the index page"
    ],
    show_fields: [
      type: {:list, :atom},
      doc: "list of fields to show on the show page"
    ],
    edit_fields: [
      type: {:list, :atom},
      doc: "list of fields to show on the edit/new page"
    ]
  ]

  alias Blank.Context
  use Blank.Web, :live_view

  embed_templates("admin_page/*")

  @callback repo() :: atom()

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
    default_edit_fields = Enum.reject(default_fields, &(&1 in [:inserted_at, :updated_at]))

    opts =
      opts
      |> Keyword.put_new_lazy(:name, fn -> Atom.to_string(opts[:key]) end)
      |> Keyword.put_new(:plural_name, opts[:schema].__schema__(:source))
      |> Keyword.put_new(:index_fields, default_fields)
      |> Keyword.put_new(:show_fields, default_edit_fields)
      |> Keyword.put_new(:edit_fields, default_edit_fields)

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
      def handle_event(event, params, socket), do: AdminPage.handle_event(event, params, socket)

      @impl Phoenix.LiveView
      def render(assigns), do: AdminPage.render(assigns)

      @impl Blank.AdminPage
      def config(key), do: Keyword.fetch!(@config_opts, key)

      @impl Blank.AdminPage
      def repo,
        do:
          Keyword.get(
            @config_opts,
            :repo,
            Application.get_env(
              :blank,
              :repo
            )
          )
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

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    admin_page = socket.view

    schema = admin_page.config(:schema)
    primary_key = Blank.Schema.primary_key(struct(schema))

    {:ok,
     socket
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

    search = !Map.has_key?(params, "filters") or 
      Map.get(params, "filters", []) |> Enum.any?(fn {_, v} -> v["field"] == "search" end) |> dbg()
    
    filter_fields = 
      if search do
        @search_field
      else
        advanced_search(fields)
      end

    case Context.paginate_schema(repo, schema, params, fields) do
      {:ok, {items, meta}} ->
        socket
        |> assign(:meta, meta)
        |> assign(:item, nil)
        |> assign(:fields, fields)
        |> assign(:filter_fields, filter_fields)
        |> assign(:modal_fields, modal_fields)
        |> stream(:items, items, reset: true)

      {:error, _meta} ->
        push_navigate(socket, to: socket.assigns.active_link.url)
    end
  end

  defp get_field_definitions(struct, fields) do
    Stream.map(fields, &{&1, Blank.Schema.get_field(struct, &1)})
    |> Enum.filter(&Map.get(elem(&1, 1), :viewable, true))
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
    {:ok, _} = Context.delete(socket.assigns.repo, item)

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
      {name, %{filter_key: key, label: label}} ->
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
    case Context.update(socket.assigns.repo, socket.assigns.item, params) do
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
    case Context.create(socket.assigns.repo, socket.assigns.item, params) do
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

  @decode_fields [Blank.Fields.BelongsTo, Blank.Fields.Location]
  defp decode(value, fields) do
    fields
    |> Stream.filter(&(elem(&1, 1).module in @decode_fields))
    |> Enum.reduce(value, fn {key, _}, acc ->
      Map.update(acc, Atom.to_string(key), nil, fn selected ->
        case selected do
          nil -> []
          "" -> nil
          selected when is_list(selected) -> Enum.map(selected, &decode_value/1)
          selected -> decode_value(selected)
        end
      end)
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
