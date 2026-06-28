# How to Write a Custom Field

This guide walks through creating a custom Field module — a LiveComponent that controls how a data type is rendered in list, display, and form views.

## Overview

A Field is a Phoenix LiveComponent implementing the `Blank.Field` behaviour. You provide three render callbacks:

- `render_list/1` — shown in the index table row.
- `render_display/1` — shown on the show/detail page.
- `render_form/1` — shown on the edit/new page.

Blank ships with built-in fields (`Blank.Fields.Text`, `Blank.Fields.Boolean`, etc.) but you can create your own for domain-specific rendering.

## Step 1: Define the module

Start with the built-in `Blank.Fields.QRCode` module as a reference, or the QRCode example in the `Blank.Field` moduledoc:

```elixir
defmodule MyApp.Fields.QRCode do
  @schema [
    path: [
      type: :string,
      doc: "The path from the base url for the code to be applied to"
    ]
  ]

  use Blank.Field, schema: @schema
```

The `@schema` keyword list defines custom options that extend the default field schema. You can add any NimbleOptions-compatible types here.

## Step 2: Implement the callbacks

```elixir
  @impl Phoenix.LiveComponent
  def update(%{value: value} = assigns, socket) do
    path = Map.get(assigns.definition, :path, "/")
    path_prefix = Map.get(assigns, :path_prefix, "/")

    download_path =
      path_prefix
      |> URI.parse()
      |> URI.append_path("/qrcode")
      |> URI.append_query(URI.encode_query(%{code: value, path: path}))
      |> URI.to_string()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:qr_code, Blank.Utils.QRCode.svg(value, path))
     |> assign(:download_path, download_path)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Blank.Field
  def render_list(assigns) do
    ~H"""
    <div>
      <span>{@value}</span>
    </div>
    """
  end

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="inline-flex flex-col items-center justify-center space-y-4 p-4 bg-base-200 shadow rounded-xl">
        <div class="rounded-lg overflow-hidden inline-block bg-base-100">
          {raw(@qr_code)}
        </div>
        <span class="font-bold text-xl">{@value}</span>
        <.link href={@download_path} target="_blank">
          <.button>
            <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> Download
          </.button>
        </.link>
      </div>
    </div>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input field={@field} type="text" label={@definition.label} disabled={@definition.readonly} />
    </div>
    """
  end
end
```

Key things to note:

- `update/2` receives assigns including `:value`, `:definition` (the field options), `:schema`, and `:time_zone`.
- `render_list/1`, `render_display/1`, and `render_form/1` receive assigns and must return `%Phoenix.LiveView.Rendered{}`.
- `render_list/1` is optional — if omitted, `render_display/1` is used.

## Step 3: Wire it up

Set the `:module` option on the field in your Blank Schema derivation:

```elixir
@derive {
  Blank.Schema,
  fields: [
    barcode: [module: MyApp.Fields.QRCode, path: "/items"]
  ]
}
```

That's it — Blank will now use your custom field whenever it renders the `barcode` field.

## Tips

- Use the shared field options (`:label`, `:readonly`, `:placeholder`) via `@definition` assigns.
- For association fields, consider inheriting from `Blank.Fields.BelongsTo` or `Blank.Fields.HasMany`.
- The `path_prefix` assign is threaded through from the router's `blank_admin` mount point — use it to build correct URLs.
- Custom schema options are validated by NimbleOptions at compile time, so typos in field config will surface early.
