defmodule Blank.Schema.Validator do
  @moduledoc false

  @field_schema [
    filter_key: [
      type: :atom,
      doc: "Key for filtering (auto generated)"
    ],
    module: [
      type: :atom,
      doc: "The rendering module"
    ],
    label: [
      type: :string,
      doc: "The label to use when rendering"
    ],
    placeholder: [
      type: :string,
      doc: "The placeholder to use when rendering"
    ],
    searchable: [
      type: :boolean,
      doc: "Defines whether the field is searchable"
    ],
    sortable: [
      type: :boolean,
      doc: "Defines whether the field can be sorted by"
    ],
    viewable: [
      type: :boolean,
      doc: "Defines whether a field can be viewed on admin pages"
    ],
    readonly: [
      type: :boolean,
      doc: "Makes the field readonly and cannot be edited"
    ],
    display_field: [
      type: :atom,
      doc: "The field to use when displaying an association"
    ],
    select: [
      type: :any,
      # type: {:struct, Ecto.Query.DynamicExpr},
      doc: "Defines a select to be added when the field is loaded"
    ]
  ]

  @schema [
    identity_field: [
      type: :atom,
      doc: "Defines which field is used ad the name for the record",
      default: :id
    ],
    primary_key: [
      type: :atom,
      doc: "Defines which field is used to get an item",
      default: :id
    ],
    create_changeset: [
      type: {:fun, 2},
      doc: "The changeset to use when creating a new object"
    ],
    update_changeset: [
      type: {:fun, 2},
      doc: "The changeset to use when edition an object"
    ],
    include_foreign_keys: [
      type: :boolean,
      doc: "If to include foreign keys in the available fields",
      default: false
    ],
    fields: [
      type: :non_empty_keyword_list,
      keys: [
        *: [
          type: :non_empty_keyword_list,
          keys: @field_schema
        ]
      ]
    ],
    flop_opts: [
      type: :keyword_list
    ]
  ]

  @doc false
  def field_schema, do: @field_schema

  def validate!(opts, caller) do
    flop_schema =
      Flop.NimbleSchemas.schema_option_schema()
      |> Keyword.drop([:filterable, :sortable])
      |> NimbleOptions.new!()

    opts =
      Flop.NimbleSchemas.validate!(
        Keyword.get(opts, :flop_opts, []),
        flop_schema,
        Flop.Schema,
        caller
      )
      |> then(&Keyword.put(opts, :flop_opts, &1))

    schema =
      update_in(@schema, [:fields, :keys, :*, :keys], &Keyword.merge(&1, field_schemas()))

    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        opts

      {:error, err} ->
        raise Blank.Errors.InvalidConfigError.from_nimble(err,
                caller: caller,
                module: Blank.Schema,
                usage: "@derive"
              )
    end
  end

  @fields [
    Blank.Fields.BelongsTo,
    Blank.Fields.Boolean,
    Blank.Fields.DateTime,
    Blank.Fields.HasMany,
    Blank.Fields.Location,
    Blank.Fields.Password,
    Blank.Fields.QRCode,
    Blank.Fields.Text
  ]
  defp field_schemas do
    @fields
    |> Stream.map(&apply(&1, :__schema__, []))
    |> Enum.concat()
  end

  def validate_field!(schema, caller, opts) do
    field_schema = Keyword.merge(@field_schema, schema)

    case NimbleOptions.validate(opts, field_schema) do
      {:ok, opts} ->
        opts

      {:error, err} ->
        raise Blank.Errors.InvalidConfigError.from_nimble(err,
                module: Blank.Schema,
                caller: caller,
                usage: "@derive"
              )
    end
  end
end
