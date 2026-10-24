defmodule Blank.Schema.FlopOptions do
  @moduledoc false

  # Registered from Blank's derive *before* `Flop.Schema`'s own
  # `@before_compile` hook, so Flop builds `__flop_schema__/0` from the options
  # this hook writes back.
  #
  # Two adjustments are made at hook time, where the finished struct and its
  # field types are available:
  #
  #   * the compound `:search` field keeps only members that Flop can match with
  #     `:ilike_and`. A `:binary_id` or `:binary` member would otherwise make
  #     every simple search fail in the database with
  #     `function ilike(uuid, unknown) does not exist`.
  #   * `:default_order` mirrors Blank's own `order_field/1`, so a request
  #     without ordering gets the same stable order Blank's `list_query/2`
  #     applies. Flop validates `:default_order` against `:sortable`, so the
  #     order field is added to `:sortable` when the consumer left it out.
  defmacro __before_compile__(env) do
    module = env.module
    order_field = Module.get_attribute(module, :blank_order_field)

    opts =
      Module.get_attribute(module, :flop_options)
      |> narrow_search(module)
      |> put_default_order(order_field, module)

    Module.put_attribute(module, :flop_options, opts)

    quote do: :ok
  end

  @doc false
  @spec operator(module(), atom()) :: Flop.Filter.op()
  def operator(module, field) do
    if :ilike_and in Flop.Filter.allowed_operators(module, field) do
      :ilike_and
    else
      :==
    end
  end

  defp narrow_search(opts, module) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    case Keyword.get(adapter_opts, :compound_fields, [])[:search] do
      nil -> opts
      search -> put_search(opts, adapter_opts, module, search)
    end
  end

  defp put_search(opts, adapter_opts, module, search) do
    kept = Enum.filter(search, &searchable?(&1, module, adapter_opts))

    case kept do
      [] ->
        opts
        |> Keyword.put(:adapter_opts, Keyword.put(adapter_opts, :compound_fields, []))
        |> Keyword.update(:filterable, [], &List.delete(&1, :search))

      kept ->
        Keyword.put(
          opts,
          :adapter_opts,
          Keyword.put(adapter_opts, :compound_fields, search: kept)
        )
    end
  end

  # A member whose type cannot be determined is kept: guessing would drop a
  # field that works.
  defp searchable?(name, module, adapter_opts) do
    case join_field_type(adapter_opts, name) || schema_field_type(module, name) do
      nil -> true
      type -> :ilike_and in Flop.Filter.allowed_operators(type)
    end
  end

  defp join_field_type(adapter_opts, name) do
    case Keyword.get(Keyword.get(adapter_opts, :join_fields, []), name) do
      nil -> nil
      opts when is_list(opts) -> Keyword.get(opts, :ecto_type)
      opts when is_map(opts) -> Map.get(opts, :ecto_type)
    end
  end

  # `module.__schema__/1` is not callable while the module compiles, so the
  # Ecto attributes Ecto.Schema.__schema__/1 itself reads are used instead.
  defp schema_field_type(module, name) do
    case List.keyfind(Module.get_attribute(module, :ecto_fields), name, 0) do
      {^name, {type, _writable}} ->
        type

      nil ->
        case List.keyfind(Module.get_attribute(module, :ecto_virtual_fields), name, 0) do
          {^name, type} -> type
          nil -> nil
        end
    end
  end

  defp put_default_order(opts, order_field, module) do
    case resolve_order(order_field, module) do
      nil -> opts
      {field, direction} -> maybe_put_default_order(opts, field, direction)
    end
  end

  defp maybe_put_default_order(opts, field, direction) do
    case Keyword.fetch(opts, :default_order) do
      {:ok, _consumer_order} ->
        opts

      :error ->
        sortable = Keyword.get(opts, :sortable, [])

        opts
        |> Keyword.put(:sortable, Enum.uniq([field | sortable]))
        |> Keyword.put(:default_order, %{order_by: [field], order_directions: [direction]})
    end
  end

  defp resolve_order(nil, module) do
    case module |> Module.get_attribute(:ecto_primary_keys) |> Enum.reverse() do
      [field | _] -> {field, :asc}
      [] -> nil
    end
  end

  defp resolve_order({field, direction}, _module)
       when is_atom(field) and direction in [:asc, :desc],
       do: {field, direction}

  defp resolve_order(field, _module) when is_atom(field), do: {field, :asc}
  defp resolve_order(_other, _module), do: nil
end
