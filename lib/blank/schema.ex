defprotocol Blank.Schema do
  @moduledoc """
  Protocol for querying info from Ecto schemas.

  ## Available options

  #{NimbleOptions.docs(Blank.Schema.Validator.__schema__())}

  ## Example

      @derive {
        Blank.Schema,
        fields: [
          authors: [
            display_field: :full_name,
            searchable: true,
            sortable: true,
            select: quote(do: dynamic([p], fragment("concat(?, ' ', ?)", p.first_name, p.last_name))),
            children: [
              first_name: [],
              last_name: []
            ]
          ],
          content: [
            viewable: false
          ]
        ],
        identity_field: :people,
        order_field: :inserted_at
      }
  """

  @type action() :: :new | :edit

  @doc """
  Returns the display name of a struct

  Uses the `identity_field` option and if the value is a struct itself, then the
  `display_field` is used.
  """
  @spec name(any()) :: String.t()
  def name(data)

  @doc """
  Returns the primary keys of the struct

  By default this is usually the `:id` key.
  """
  @spec primary_keys(any()) :: [atom()]
  def primary_keys(data)

  @doc """
  Returns the changeset function that is to be used

  Depending on the action, this could be the `:create_changeset` option or the
  `:update_changeset` option.
  """
  @spec changeset(any(), action()) :: function()
  def changeset(data, action)

  @doc """
  Returns the field definition for key

  The field definition is validated on fetch due to the schema being dynamic.
  """
  @spec get_field(any(), atom()) :: Blank.Field.t()
  def get_field(data, field)

  @doc """
  Returns the identity field option
  """
  @spec identity_field(any()) :: atom()
  def identity_field(data)

  @doc """
  Returns the order field options
  """
  @spec order_field(any()) :: atom()
  def order_field(data)
end

defimpl Blank.Schema, for: Any do
  alias Blank.Schema.Validator

  @instructions """
  Blank.Schema protocol must always be explicitly implemented.

  To do this, you have to derive Blank.Schema in your Ecto schema module. For
  example: 

      @derive {
        Blank.Schema,
        fields: [
          authors: [
            display_field: :full_name,
            searchable: true,
            sortable: true,
            select: quote(do: dynamic([p], fragment("concat(?, ' ', ?)", p.first_name, p.last_name))),
            children: [
              first_name: [],
              last_name: []
            ]
          ],
          content: [
            viewable: false
          ]
        ],
        identity_field: :people,
        order_field: :inserted_at
      }

      schema "posts" do
        field :content, :string

        has_many :people, Person, on_delete: :delete_all, on_replace: :delete
      end

  """
  defmacro __deriving__(module, struct, options) do
    options =
      Validator.validate!(
        options,
        __CALLER__.module
      )

    create_changeset =
      Keyword.get(options, :create_changeset, Function.capture(module, :changeset, 2))

    update_changeset =
      Keyword.get(options, :update_changeset, Function.capture(module, :changeset, 2))

    flop_derive = get_flop_opts(module, __CALLER__.module, struct, options)
    field_def_funcs = build_field_def_func(struct, options)

    identity_field = Keyword.fetch!(options, :identity_field)

    order_field =
      Keyword.fetch!(options, :order_field)
      |> default_order()

    quote do
      unquote(flop_derive)

      defimpl Blank.Schema, for: unquote(module) do
        @impl Blank.Schema
        def name(struct) do
          unquote(__MODULE__).__name__(struct, unquote(identity_field))
        end

        @impl Blank.Schema
        def primary_keys(%{__struct__: schema}) when is_atom(schema) do
          schema.__schema__(:primary_key)
        end

        @impl Blank.Schema
        def identity_field(%{__struct__: schema} = struct) when is_atom(schema) do
          with nil <- unquote(identity_field),
               [pk | _] <- Blank.Schema.primary_keys(struct) do
            pk
          else
            res when is_atom(res) ->
              res

            _ ->
              raise ArgumentError, "No primary keys for module #{schema}"
          end
        end

        @impl Blank.Schema
        def order_field(%{__struct__: schema} = struct) when is_atom(schema) do
          with nil <- unquote(order_field),
               [pk | _] <- Blank.Schema.primary_keys(struct) do
            {pk, :asc}
          else
            {_, _} = res ->
              res

            _ ->
              raise ArgumentError, "No primary keys for module #{schema}"
          end
        end

        @impl Blank.Schema
        def changeset(struct, :new), do: unquote(create_changeset)
        def changeset(struct, :edit), do: unquote(update_changeset)

        unquote(field_def_funcs)
      end
    end
  end

  @doc false
  def __name__(struct, identity_field) do
    Map.get(struct, identity_field)
    |> get_name(struct, identity_field)
  end

  defp get_name(val, struct, identity_field) when is_list(val) do
    Enum.map_join(val, ", ", &get_name(&1, struct, identity_field))
  end

  defp get_name(val, struct, identity_field) when is_map(val) do
    Blank.Schema.get_field(struct, identity_field)
    |> Map.get_lazy(:display_field, fn -> Blank.Schema.identity_field(val) end)
    |> then(&Map.fetch!(val, &1))
  end

  defp get_name(val, _struct, _identity_field), do: val

  defp default_order(nil), do: nil

  defp default_order({field, direction}) when is_atom(field) and direction in [:asc, :desc],
    do: {field, direction}

  defp default_order(field) when is_atom(field), do: {field, :asc}

  defp get_flop_opts(module, caller, struct, options) do
    {searchable, sortable, adapter_opts} =
      Keyword.get(options, :fields, [])
      |> get_filterable_fields()

    flop_opts =
      Keyword.fetch!(options, :flop_opts)
      |> Keyword.merge(
        filterable: searchable,
        sortable: sortable,
        adapter_opts: adapter_opts
      )

    adapter = Keyword.fetch!(flop_opts, :adapter)

    adapter_opts = Keyword.fetch!(flop_opts, :adapter_opts)

    adapter_opts =
      adapter.init_schema_opts(flop_opts, adapter_opts, caller, struct)

    flop_opts = Keyword.put(flop_opts, :adapter_opts, adapter_opts)

    filterable_fields = Keyword.get(flop_opts, :filterable)
    sortable_fields = Keyword.get(flop_opts, :sortable)
    default_limit = Keyword.get(flop_opts, :default_limit)
    max_limit = Keyword.get(flop_opts, :max_limit)
    pagination_types = Keyword.get(flop_opts, :pagination_types)
    default_pagination_type = Keyword.get(flop_opts, :default_pagination_type)
    default_order = Keyword.get(flop_opts, :default_order)

    field_info_func = build_field_info_func(adapter, adapter_opts, struct)
    get_field_func = build_get_field_func(struct, adapter, adapter_opts)

    quote do
      defimpl Flop.Schema, for: unquote(module) do
        import Ecto.Query

        require Logger

        def default_limit(_) do
          unquote(default_limit)
        end

        def default_order(_) do
          unquote(Macro.escape(default_order))
        end

        unquote(field_info_func)
        unquote(get_field_func)

        def filterable(_) do
          unquote(filterable_fields)
        end

        def max_limit(_) do
          unquote(max_limit)
        end

        def pagination_types(_) do
          unquote(pagination_types)
        end

        def default_pagination_type(_) do
          unquote(default_pagination_type)
        end

        def sortable(_) do
          unquote(sortable_fields)
        end
      end
    end
  end

  def build_field_info_func(adapter, adapter_opts, struct) do
    for {name, field_info} <- adapter.fields(struct, adapter_opts) do
      case field_info do
        %{ecto_type: {:from_schema, module, field}} ->
          quote do
            def field_info(_, unquote(name)) do
              %{
                unquote(Macro.escape(field_info))
                | ecto_type: unquote(module).__schema__(:type, unquote(field))
              }
            end
          end

        %{ecto_type: {:ecto_enum, values}} ->
          type = Ecto.ParameterizedType.init(Ecto.Enum, values: values)
          field_info = %{field_info | ecto_type: type}

          quote do
            def field_info(_, unquote(name)) do
              unquote(Macro.escape(field_info))
            end
          end

        _ ->
          quote do
            def field_info(_, unquote(name)) do
              unquote(Macro.escape(field_info))
            end
          end
      end
    end
  end

  def build_get_field_func(struct, adapter, adapter_opts) do
    for {field, field_info} <- adapter.fields(struct, adapter_opts) do
      quote do
        def get_field(struct, unquote(field)) do
          unquote(adapter).get_field(
            struct,
            unquote(field),
            unquote(Macro.escape(field_info))
          )
        end
      end
    end
  end

  defp get_filterable_fields([]), do: {[], [], []}

  defp get_filterable_fields(fields) do
    {searchable, sortable, join_opts} =
      Enum.reduce(fields, {[], [], []}, fn {name, value}, {acc_search, acc_sort, j_opts} ->
        searchable = Keyword.get(value, :searchable, false)
        sortable = Keyword.get(value, :sortable, false)

        {search_name, j_opts} =
          searchable_field_and_opts(
            name,
            searchable ||
              sortable,
            value,
            j_opts
          )

        {maybe_add(acc_search, searchable, search_name),
         maybe_add(acc_sort, sortable, search_name), j_opts}
      end)

    adapter_opts = [
      join_fields: join_opts,
      compound_fields: [
        search: searchable
      ]
    ]

    {[:search | searchable], sortable, adapter_opts}
  end

  defp joined_name(name, def) do
    if display = Keyword.get(def, :display_field) do
      String.to_atom("#{name}_#{display}")
    else
      name
    end
  end

  defp searchable_field_and_opts(name, false, _value, j_opts), do: {name, j_opts}

  defp searchable_field_and_opts(name, true, value, j_opts) do
    if display = Keyword.get(value, :display_field) do
      join_name = joined_name(name, value)

      {join_name,
       Keyword.put(j_opts, join_name,
         binding: name,
         field: display,
         ecto_type: :string
       )}
    else
      {name, j_opts}
    end
  end

  defp maybe_add(acc, true, val), do: [val | acc]
  defp maybe_add(acc, _false, _val), do: acc

  defp build_field_def_func(struct, opts) do
    for field <- schema_fields(struct) do
      field_def =
        Keyword.get(opts, :fields, [])
        |> static_field_def(field)

      quote do
        @impl Blank.Schema
        def get_field(struct, unquote(field)) do
          {module, opts} =
            unquote(__MODULE__).put_field_module(
              unquote(field_def),
              unquote(field),
              struct.__struct__
            )

          opts
          |> module.validate_field!()
          |> then(&Blank.Field.new!(unquote(field), &1))
        end
      end
    end
  end

  defp static_field_def(field_defs, field) do
    def = Keyword.get(field_defs, field, [])

    default_for_field(field)
    |> Keyword.merge(def)
    |> Keyword.put_new(:filter_key, joined_name(field, def))
  end

  @doc false
  def put_field_module(field_def, field, schema) do
    module =
      case {schema.__schema__(:type, field), schema.__schema__(:association, field)} do
        {nil, %Ecto.Association.BelongsTo{}} ->
          Blank.Fields.BelongsTo

        {nil, %Ecto.Association.Has{}} ->
          Blank.Fields.HasMany

        {{:array, _}, nil} ->
          Blank.Fields.List

        {type, _} ->
          Blank.Field.module_for_type(type)
      end

    opts = Keyword.put_new(field_def, :module, module)

    {Keyword.fetch!(opts, :module), opts}
  end

  defp default_for_field(:id) do
    [
      label: "ID",
      readonly: true
    ]
  end

  defp default_for_field(:__id__) do
    [
      label: "Arango ID",
      readonly: true
    ]
  end

  defp default_for_field(_), do: []

  defp schema_fields(struct) do
    struct
    |> Map.from_struct()
    |> Stream.reject(fn
      {:__meta__, _} -> true
      _ -> false
    end)
    |> Enum.map(&elem(&1, 0))
  end

  def name(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  def primary_keys(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  def changeset(struct, _) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  def get_field(struct, _) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  def identity_field(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  def order_field(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end
end
