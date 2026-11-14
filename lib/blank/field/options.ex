defmodule Blank.Field.Options do
  @moduledoc false

  @schema [
    filter_key: [
      type: :atom,
      doc: "Key for filtering (auto generated)"
    ],
    module: [
      type: :atom,
      doc:
        "The rendering module, see `Blank.Field` for more info. The bare `%Blank.Field{}` leaves it `nil`; `Blank.Fields.new!/2` fills it, defaulting to `Blank.Fields.Text`."
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

  @spec __schema__() :: keyword()
  def __schema__, do: @schema
end
