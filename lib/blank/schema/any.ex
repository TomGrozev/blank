defimpl Blank.Schema, for: Any do
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
      Blank.Schema.Options.validate!(
        options,
        __CALLER__.module,
        Blank.Fields.__aggregate_field_schemas__()
      )

    create_changeset =
      Keyword.get(options, :create_changeset, Function.capture(module, :changeset, 2))

    update_changeset =
      Keyword.get(options, :update_changeset, Function.capture(module, :changeset, 2))

    flop_derive = get_flop_opts(options)
    field_def_funcs = build_field_def_func(struct, options)

    identity_field = Keyword.fetch!(options, :identity_field)

    order_field =
      Keyword.fetch!(options, :order_field)
      |> default_order()

    quote do
      unquote(flop_derive)

      defimpl Blank.Schema, for: unquote(module) do
        @impl true
        def name(struct) do
          unquote(__MODULE__).__name__(struct, unquote(identity_field))
        end

        @impl true
        def primary_keys(%{__struct__: schema}) when is_atom(schema) do
          schema.__schema__(:primary_key)
        end

        @impl true
        def identity_field(%{__struct__: schema} = struct) when is_atom(schema) do
          unquote(identity_field_body(identity_field))
        end

        @impl true
        def order_field(%{__struct__: schema} = struct) when is_atom(schema) do
          unquote(order_field_body(order_field))
        end

        @impl true
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

  # A configured identity field is a literal atom, so the generated clause returns
  # it directly. Only the default `nil` needs the primary-key fallback, and building
  # that branch only for `nil` keeps `with nil <- :email` out of the generated code.
  defp identity_field_body(nil) do
    quote do
      case Blank.Schema.primary_keys(struct) do
        [pk | _] -> pk
        _ -> raise ArgumentError, "No primary keys for module #{schema}"
      end
    end
  end

  defp identity_field_body(field) when is_atom(field), do: field

  # `default_order/1` already turned a configured atom into a tuple, so only `nil`
  # needs the primary-key fallback. Generating that branch only for `nil` keeps
  # `with nil <- {:rating, :desc}` out of the generated code.
  defp order_field_body(nil) do
    quote do
      case Blank.Schema.primary_keys(struct) do
        [pk | _] -> {pk, :asc}
        _ -> raise ArgumentError, "No primary keys for module #{schema}"
      end
    end
  end

  defp order_field_body(field), do: field

  defp default_order(nil), do: nil

  defp default_order({field, direction}) when is_atom(field) and direction in [:asc, :desc],
    do: {field, direction}

  defp default_order(field) when is_atom(field), do: {field, :asc}

  defp get_flop_opts(options) do
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

    # Flop 0.29 defaults :max_filters to 20, but Blank's advanced search submits
    # one filter per searchable field, so a wider schema fails every submit.
    # :search is the virtual full-text field, not a filter row, so it does not
    # count. Keyword.put_new keeps an explicit :max_filters from the consumer.
    filter_count = Enum.count(searchable, &(&1 != :search))
    flop_opts = put_max_filters(flop_opts, filter_count)

    # Flop 0.29 builds the schema config in its own __before_compile__ from
    # @flop_options: it runs init_schema_opts/4, fields/2 and the option
    # validation there, on the finished struct. Blank's hook runs first, so it
    # can read the struct's field types and rewrite @flop_options before Flop
    # sees it; see Blank.Schema.FlopOptions.
    quote do
      @behaviour Flop.Schema
      @blank_order_field unquote(Macro.escape(Keyword.get(options, :order_field)))
      @flop_options unquote(Macro.escape(flop_opts))
      @before_compile Blank.Schema.FlopOptions
      @before_compile Flop.Schema
    end
  end

  defp put_max_filters(flop_opts, filter_count) when filter_count > 20,
    do: Keyword.put_new(flop_opts, :max_filters, filter_count)

  defp put_max_filters(flop_opts, _filter_count), do: flop_opts

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

  # sobelow_skip ["DOS.StringToAtom"]
  # Name and display are compile-time schema field names
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
        @impl true
        def get_field(struct, unquote(field)) do
          {module, opts} =
            Blank.Fields.put_field_module(
              unquote(field_def),
              unquote(field),
              struct.__struct__
            )

          opts
          |> module.validate_field!()
          |> then(&Blank.Fields.new!(unquote(field), &1))
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

  @impl true
  def name(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  @impl true
  def primary_keys(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  @impl true
  def changeset(struct, _) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  @impl true
  def get_field(struct, _) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  @impl true
  def identity_field(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end

  @impl true
  def order_field(struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: @instructions
  end
end
