# AdminPage Options Quick Reference

Quick-reference for the options passed to `use Blank.AdminPage`. See the `Blank.AdminPage` moduledoc for the full documentation.

## Required

| Option | Type | Description |
|---|---|---|
| `:schema` | `atom()` | The Ecto schema module this page manages. |

## Naming

| Option | Type | Default | Description |
|---|---|---|---|
| `:name` | `String.t()` | downcased schema name | Singular display name (e.g. `"product"`). |
| `:plural_name` | `String.t()` | schema source (table name) | Plural display name (e.g. `"products"`). |
| `:key` | `atom()` | downcased schema name | Atom key for the schema in internal lookups. |
| `:icon` | `String.t()` | `nil` | Hero icon class for the sidebar (e.g. `"hero-archive-box"`). |

## Field lists

| Option | Type | Default | Description |
|---|---|---|---|
| `:index_fields` | `[atom()]` | all schema fields minus foreign keys | Fields shown on the index page. |
| `:show_fields` | `[atom()]` | index_fields minus timestamps | Fields shown on the show page. |
| `:edit_fields` | `[atom()]` | index_fields minus timestamps | Fields shown on the edit/new page. |

## Index page

| Option | Type | Default | Description |
|---|---|---|---|
| `:index_buttons` | `keyword_list` | `[]` (new, import, export enabled) | Buttons on the index page. Set `:new`, `:import`, or `:export` to `nil` to disable. |

Each button accepts: `:icon`, `:text` (supports `{name}` / `{plural_name}` templates), `:variant`, `:action` (`:patch` / `:navigate` / function), `:path`.

## Statistics

| Option | Type | Default | Description |
|---|---|---|---|
| `:stats` | `non_empty_keyword_list` | `[total: [...]]` | Stats displayed above the index. Set to `[]` to disable. |

Each stat entry accepts:

| Key | Type | Default | Description |
|---|---|---|---|
| `:name` | `String.t() \| nil` | auto-generated | Display label. |
| `:display` | `atom()` | `Blank.Stats.Value` | Stats module implementing `Blank.Stats`. |
| `:formatter` | `(module(), number() -> String.t()) \| nil` | `&Blank.Stats.named_value/2` | Value formatter function. |

## Other

| Option | Type | Description |
|---|---|---|
| `:repo` | `atom()` | Override the Ecto Repo (defaults to the app config `:repo`). |

## Examples

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  use Blank.AdminPage,
    schema: MyApp.Products.Product,
    icon: "hero-cube",
    name: "product",
    plural_name: "products",
    index_fields: [:title, :price, :active],
    show_fields: [:title, :price, :active, :inserted_at],
    edit_fields: [:title, :price, :active],
    stats: [
      total: [],
      in_stock: [name: "In stock", display: MyApp.Stats.InStock]
    ]
end
```
