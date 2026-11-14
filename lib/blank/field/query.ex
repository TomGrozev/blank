defmodule Blank.Field.Query do
  @moduledoc false
  import Ecto.Query

  # Not exercised by the suite: the test database is SQLite, which has no ilike/2;
  # only Postgres runs this builder.
  @doc """
  Generates an options query
  """
  @spec options_query(Ecto.Repo.t(), Ecto.Schema.t(), Blank.Field.t(), Ecto.Query.t()) ::
          [struct()]
  def options_query(repo, schema, field_def, query) do
    from(item in schema)
    |> apply_search(query, schema, field_def)
    |> maybe_select(field_def)
    |> repo.all()
  end

  defp apply_search(query, search_query, schema, field_def) do
    schema_struct = struct(schema)

    fields = schema.__schema__(:fields)

    select = Map.get(field_def, :select)

    searchable_fields =
      case Blank.Schema.impl_for(schema_struct) do
        nil ->
          fields
          |> Stream.reject(
            &(schema.__schema__(:type, &1) in ([:utc_datetime, :__id__] ++
                                                 schema.__schema__(:primary_keys)))
          )
          |> Enum.map(&{&1, nil})

        _ ->
          Stream.map(fields, fn
            field ->
              def = Blank.Schema.get_field(schema_struct, field)

              {field, def}
          end)
          |> Enum.filter(fn {_, def} -> Map.get(def, :searchable, true) end)
      end

    if Enum.empty?(searchable_fields) do
      raise ArgumentError, "no searchable fields for #{field_def.key}"
    end

    conditions = search_conditions(searchable_fields, "%#{search_query}%", select)
    where(query, ^conditions)
  end

  defp search_conditions([field], query, select) do
    search_condition(field, query, select)
  end

  defp search_conditions([field | tail], query, select) do
    dynamic(^search_condition(field, query, select) or ^search_conditions(tail, query, select))
  end

  defp search_condition({_name, %{select: select}}, query, _select) when not is_nil(select) do
    dynamic(ilike(^select, ^query))
  end

  defp search_condition({name, nil}, query, nil) do
    dynamic([c], ilike(field(c, ^name), ^query))
  end

  defp search_condition({_name, nil}, query, select) do
    dynamic(ilike(^select, ^query))
  end

  defp search_condition({name, def}, query, _select) do
    display_field = Map.get(def, :display_field) || name

    dynamic([c], ilike(field(c, ^display_field), ^query))
  end

  defp maybe_select(query, %{display_field: display_field, select: select})
       when not is_nil(select) do
    query
    |> select_merge(^%{display_field => select})
  end

  defp maybe_select(query, _), do: query
end
