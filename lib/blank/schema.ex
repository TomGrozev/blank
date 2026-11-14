defmodule Blank.Schema.Options do
  @moduledoc false

  alias Blank.Errors.InvalidConfigError

  @schema [
    identity_field: [
      type: :atom,
      doc: """
      Defines which field is used as the name for the record

      A value of `nil` (default) will use the first primary_key.
      """,
      default: nil
    ],
    create_changeset: [
      type: {:fun, 2},
      doc: "The changeset to use when creating a new object"
    ],
    update_changeset: [
      type: {:fun, 2},
      doc: "The changeset to use when updating an object"
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
          keys: Blank.Field.Options.__schema__()
        ]
      ],
      doc: """
      All options specified below apply to all field definitions.

      Based on the module specified, additional options can be supplied. Refer
      to the module for more info on available options.
      """
    ],
    order_field: [
      type:
        {:or,
         [
           :atom,
           {:tuple, [:atom, {:in, [:asc, :desc]}]}
         ]},
      doc: """
      Defines which field is used to order a list.

      Accepts either the field name and defaults to ascending order.
      Otherwise accepts a two element tuple, where the first element
      is the field name and the second is the direction (either `:asc`
      or `:desc`).

      A value of `nil` (default) will use the first primary_key.
      """,
      default: nil
    ],
    flop_opts: [
      type: :keyword_list,
      doc: "Options that are passed to flop, see the flop docs for more info."
    ]
  ]

  @spec __schema__() :: keyword()
  def __schema__, do: @schema

  @spec validate!(keyword(), module(), keyword()) :: keyword()
  def validate!(opts, caller, field_schemas) do
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
      update_in(
        @schema,
        [:fields, :keys, :*, :keys],
        &Keyword.merge(&1, field_schemas)
      )

    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        opts

      {:error, err} ->
        raise InvalidConfigError.from_nimble(err,
                caller: caller,
                module: Blank.Schema,
                usage: "@derive"
              )
    end
  end
end

defprotocol Blank.Schema do
  @moduledoc """
  Protocol for querying info from Ecto schemas.

  ## Available options

  #{NimbleOptions.docs(Blank.Schema.Options.__schema__())}

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
