# How to Write a Custom Exporter

This guide walks through creating a custom Exporter — an adapter that produces a downloadable file from a schema query.

## Overview

An Exporter implements the `Blank.Exporter` behaviour. Blank ships with `Blank.Exporters.CSV` and `Blank.Exporters.QRCode`, but you can add your own for any output format (text, PDF, ZIP, etc.).

## Step 1: Define the module

```elixir
defmodule MyApp.TextExporter do
  @behaviour Blank.Exporter
```

## Step 2: Implement the callbacks

```elixir
  @impl true
  def display?(_), do: true

  @impl true
  def name, do: "Text"

  @impl true
  def icon, do: "hero-document-text"

  @impl true
  def ext, do: "txt"

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
    |> Stream.map(fn {k, v} -> "#{k}: #{convert_string(v)}" end)
  end

  @impl true
  def save(stream, path) do
    stream
    |> Enum.join("\n")
    |> Stream.into(File.stream!(path, [:write, :utf8]))
    |> Stream.run()

    :ok
  end
```

### Callback reference

| Callback | Returns | Description |
|---|---|---|
| `display?(fields)` | `boolean()` | Whether this exporter should be shown for the given field set. |
| `name()` | `String.t()` | Label on the export button (e.g. `"CSV"`, `"QR Code"`). |
| `icon()` | `String.t()` | Hero icon class (optional — defaults to no icon). |
| `ext()` | `String.t()` | File extension for the export (e.g. `"csv"`, `"txt"`). |
| `process(item, fields)` | `Enumerable.t()` | Transform each row. Called lazily — the result is streamed to `save/2`. |
| `save(stream, path)` | `:ok \| {:error, any()}` | Write the stream to disk. Return `:ok` on success. |

## Step 3: Register the exporter

Add it to your application config:

```elixir
config :blank,
  additional_exporters: [MyApp.TextExporter]
```

It will now appear in the export dropdown on admin page index views.

## Tips

- `process/2` receives the raw Ecto struct and the field definitions keyword list. Use `Keyword.fetch(fields, field_name)` to get field metadata like `:display_field`.
- Keep `process/2` lazy — it's called per-row and the result is chained into `save/2`.
- `display?(fields)` lets you conditionally hide the exporter. For example, you might hide a QR code exporter if no QR-relevant fields are present.
- The `icon/0` callback is optional — if not implemented, no icon is shown on the button.
