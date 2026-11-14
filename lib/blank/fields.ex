defmodule Blank.Fields do
  @moduledoc false

  alias Blank.Field
  alias Blank.Fields.Type

  @fields [
    Blank.Fields.BelongsTo,
    Blank.Fields.Boolean,
    Blank.Fields.DateTime,
    Blank.Fields.HasMany,
    Blank.Fields.Location,
    Blank.Fields.List,
    Blank.Fields.Password,
    Blank.Fields.QRCode,
    Blank.Fields.Text
  ]

  @doc false
  @spec __aggregate_field_schemas__() :: keyword()
  def __aggregate_field_schemas__ do
    @fields
    |> Stream.map(& &1.__schema__())
    |> Enum.concat()
  end

  @doc false
  @spec new!(atom(), Keyword.t()) :: Field.t()
  def new!(key, field_def) do
    attrs =
      field_def
      |> Keyword.put(:key, key)
      |> Keyword.put_new(:module, Blank.Fields.Text)
      |> Keyword.put_new(:label, Atom.to_string(key) |> Phoenix.Naming.humanize())
      |> Keyword.update(:children, [], fn children ->
        Enum.map(children, fn {k, v} ->
          {k, new!(k, v)}
        end)
      end)

    struct(Field, attrs)
  end

  @doc false
  @spec put_field_module(keyword(), atom(), module()) :: {module(), keyword()}
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
          Type.module_for_type(type)
      end

    opts = Keyword.put_new(field_def, :module, module)

    {Keyword.fetch!(opts, :module), opts}
  end
end
