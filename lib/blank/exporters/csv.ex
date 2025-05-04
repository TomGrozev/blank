defmodule Blank.Exporters.CSV do
  @behaviour Blank.Exporter

  @impl true
  def display?(_), do: true

  @impl true
  def name, do: "CSV"

  @impl true
  def icon, do: "hero-chart-bar"

  @impl true
  def ext, do: "csv"

  @impl true
  def process(item, fields) do
    item
    |> Map.from_struct()
    |> Stream.map(fn {k, v} ->
      case Keyword.fetch(fields, k) do
        {:ok, %{display_field: nil}} ->
          {k, v}

        {:ok, %{display_field: display}} ->
          {k, get_val(v, display)}

        :error ->
          nil
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Stream.map(fn {k, v} -> {k, convert_string(v)} end)
    |> Map.new()
  end

  defp get_val(val, key) when is_list(val), do: Enum.map_join(val, ", ", &get_val(&1, key))

  defp get_val(%{} = val, key), do: Map.get(val, key)

  defp get_val(val, _), do: val

  defp convert_string(list) when is_list(list) do
    Enum.map(list, &convert_string/1)
  end

  defp convert_string(%DateTime{} = date) do
    DateTime.to_iso8601(date)
  end

  defp convert_string(other), do: other

  @impl true
  def save(stream, path) do
    stream
    |> CSV.encode(headers: true)
    |> Stream.into(File.stream!(path, [:write, :utf8]))
    |> Stream.run()

    :ok
  end
end
