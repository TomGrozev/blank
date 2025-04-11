defmodule Blank.Context do
  import Ecto.Query

  def paginate_schema(repo, schema, params, fields) do
    try do
      list_query(schema, fields)
      |> Flop.validate_and_run(params, repo: repo, for: schema)
    rescue
      Ecto.NoResultsError ->
        {:ok, {[], %Flop.Meta{current_page: 1, total_pages: 1}}}
    end
  end

  def options_query(repo, schema, field_def, query) do
    from(item in schema)
    |> apply_search(query, schema, field_def)
    |> maybe_select(field_def)
    |> repo.all()
  end

  def list_schema_by_ids(repo, schema, ids) do
    from(item in schema, where: item.id in ^ids)
    |> repo.all()
  end

  def list_schema(repo, schema, fields) do
    list_query(schema, fields)
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
          |> Stream.reject(&(schema.__schema__(:type, &1) in [:utc_datetime, :id, :__id__]))
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

  defp list_query(schema, fields) do
    assocs = get_associations(fields, schema)

    from(item in schema, as: :item)
    |> maybe_join(assocs)
    |> maybe_preload(assocs)
  end

  def get!(repo, schema, id) do
    primary_key = Blank.Schema.primary_key(struct(schema))

    from(item in schema, where: field(item, ^primary_key) == ^id)
    |> repo.one!()
  end

  def get!(repo, schema, id, fields) do
    primary_key = Blank.Schema.primary_key(struct(schema))
    assocs = get_associations(fields, schema)

    from(item in schema, where: field(item, ^primary_key) == ^id)
    |> maybe_preload(assocs)
    |> repo.one!()
  end

  defp get_associations(fields, schema) do
    fields
    |> Stream.map(fn {field, def} -> {schema.__schema__(:association, field), def} end)
    |> Enum.reject(fn {assoc, _} -> is_nil(assoc) end)
  end

  defp maybe_join(query, []), do: query

  defp maybe_join(query, assocs) do
    Enum.reduce(assocs, query, fn {assoc, field_def}, acc ->
      %{queryable: queryable, owner_key: owner_key, related_key: related_key} =
        assoc

      case field_def do
        %{key: field, select: select, display_field: display_field} when not is_nil(select) ->
          preload_query =
            from(queryable)
            |> select_merge(^%{display_field => select})

          acc
          |> join(
            :left_lateral,
            [item: i],
            a in ^subquery(preload_query),
            as: ^field,
            on: field(i, ^owner_key) == field(a, ^related_key)
          )

        %{key: field} ->
          acc
      end
    end)
  end

  def get_primary_key(%{__struct__: struct}) when is_atom(struct),
    do: get_primary_key(struct)

  def get_primary_key(module) when is_atom(module) do
    case module.__schema__(:primary_key) do
      [id] -> id
      _ -> raise ArgumentError, "No primary key for #{module}"
    end
  end

  defp maybe_preload(query, []), do: query

  defp maybe_preload(query, assocs) do
    preloads =
      Enum.map(assocs, fn {assoc, field_def} ->
        %{queryable: queryable} = assoc

        case field_def do
          %{key: field, select: select, display_field: display_field} when not is_nil(select) ->
            preload_query =
              from(queryable)
              |> select_merge(^%{display_field => select})

            {field, preload_query}

          %{key: field} ->
            field
        end
      end)

    query
    |> preload(^preloads)
  end

  def change(item, action, attrs \\ %{}) do
    changeset_function = Blank.Schema.changeset(item, action)

    item
    |> Ecto.Changeset.change()
    |> changeset_function.(attrs)
  end

  def update(repo, item, params) do
    change(item, :edit, params)
    |> repo.update()
  end

  def create(repo, item, params) do
    change(item, :new, params)
    |> repo.insert()
  end

  def create_multiple(repo, schema, params) do
    item = struct(schema)

    Enum.reduce(params, 0, fn param, acc ->
      change(item, :new, param)
      |> repo.insert()
      |> case do
        {:ok, _} ->
          acc + 1

        _ ->
          acc
      end
    end)
  end

  def delete(repo, item) do
    repo.delete(item)
  end
end
