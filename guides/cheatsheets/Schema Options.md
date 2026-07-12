# Schema Options Quick Reference

Quick-reference for the options passed when deriving `Blank.Schema` on an Ecto schema. Use `@derive {Blank.Schema, opts}` inside the schema module to configure how it appears in the admin panel.

## Basic usage

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    fields: [
      name: [module: Blank.Fields.Text],
      email: [module: Blank.Fields.Text, searchable: true],
      status: [module: Blank.Fields.Text]
    ],
    identity_field: :name
  }

  schema "users" do
    field :name, :string
    field :email, :string
    field :status, :string, default: "active"

    timestamps()
  end
end
```

## Options reference

| Option | Type | Default | Description |
|---|---|---|---|
| `:fields` | `non_empty_keyword_list` | (required) | Field definitions. Each key is a schema field name; each value is a keyword list of field options. |
| `:identity_field` | `atom() \| nil` | `nil` (first PK) | Field used as the display name for this record in association dropdowns and page titles. |
| `:order_field` | `atom() \| {atom(), :asc \| :desc} \| nil` | `nil` (first PK, ascending) | Default sort field for index listing. |
| `:create_changeset` | `fun()` | `&Module.changeset/2` | Changeset function used for create operations. |
| `:update_changeset` | `fun()` | `&Module.changeset/2` | Changeset function used for update operations. |
| `:include_foreign_keys` | `boolean()` | `false` | Include foreign key fields (e.g., `user_id`) in the available field list. |
| `:flop_opts` | `keyword()` | `[]` | Options forwarded to Flop for filtering, pagination, and sorting. See `Flop.Schema`. |

`flop_opts` accepts `:default_limit`, `:max_limit`, `:pagination_types`, `:default_pagination_type`, `:default_order`, `:adapter`, and other Flop schema options. The `:filterable` and `:sortable` lists are derived automatically from your field definitions (see `:searchable` / `:sortable` per field).

## Field options

Each entry in `:fields` accepts these common options. See `Blank.Field` for the full documentation.

| Option | Type | Default | Description |
|---|---|---|---|
| `:module` | `atom()` | auto-detected | Field adapter module (e.g., `Blank.Fields.Text`, `Blank.Fields.Boolean`). Automatically chosen based on Ecto type and associations; override to use a custom adapter. |
| `:label` | `String.t()` | humanized field name | Display label in list, show, and form views. |
| `:placeholder` | `String.t()` | `nil` | Placeholder text for form inputs. |
| `:searchable` | `boolean()` | `false` | Include this field in the advanced search filter. |
| `:sortable` | `boolean()` | `false` | Allow sorting by this field in the index view. |
| `:viewable` | `boolean()` | `true` | Show this field in admin pages. Set to `false` to hide it. |
| `:readonly` | `boolean()` | `false` | Make the field read-only in edit/new forms. |
| `:display_field` | `atom()` | `nil` | For association fields — which field on the related schema to show. Falls back to the related schema's `identity_field`. |
| `:select` | `DynamicExpr.t()` | `nil` | A custom Ecto dynamic select expression loaded with the field query. Useful for computed values on associations. |
| `:children` | `keyword()` | `[]` | Sub-field definitions for `HasMany` associations. Same shape as the top-level `:fields` option. |
| `:filter_key` | `atom()` | auto-generated | Key used for filtering in Flop. Auto-generated from the field name and `display_field`; rarely set manually. |

`id` fields (including composite PK components) default to `readonly: true` and `label: "ID"`. All other fields default to `label: nil` (humanized at build time by `Blank.Field`).

## Field types

Blank auto-detects the field adapter based on the Ecto type and association. Override with the `:module` option.

| Adapter | Auto-applied when… | Form rendering |
|---|---|---|
| `Blank.Fields.Text` | Any type not matched below (string, integer, float, decimal, naive_datetime, date) | Text input |
| `Blank.Fields.Boolean` | `:boolean` type | Checkbox |
| `Blank.Fields.DateTime` | `:utc_datetime` type | Datetime-local input; display respects Admin's timezone |
| `Blank.Fields.Currency` | — (explicit only) | Number input with `$` prefix in display |
| `Blank.Fields.Password` | — (explicit only) | Password input; display shows `************` |
| `Blank.Fields.QRCode` | — (explicit only) | Text input; display shows QR code SVG with download |
| `Blank.Fields.BelongsTo` | `belongs_to` association | Searchable select dropdown |
| `Blank.Fields.HasMany` | `has_many` / `has_one` association | Inline child list with add/remove buttons |
| `Blank.Fields.List` | `{:array, _}` type | List of items with add/remove buttons |
| `Blank.Fields.Location` | — (explicit only; requires `:geo` dep) | Address search picker |

### Type-specific options

**Blank.Fields.QRCode**

| Option | Type | Default | Description |
|---|---|---|---|
| `:path` | `String.t()` | `"/"` | Path appended to the value when generating the QR code URL. |

**Blank.Fields.Location**

Requires the optional `:geo` dependency.

| Option | Type | Description |
|---|---|---|
| `:address_fun` | `(String.t() -> {:ok, [map()]})` | 1-arity function for address search queries. Enables the address picker in forms. |

**Blank.Fields.HasMany**

| Option | Type | Default | Description |
|---|---|---|---|
| `:children` | `keyword()` | `[]` | Sub-field definitions for each child entry. Each key is a field on the child schema; values are keyword lists of field options. |

## Examples

**Simple schema with text and boolean fields:**

```elixir
@derive {
  Blank.Schema,
  fields: [
    name: [module: Blank.Fields.Text, searchable: true],
    email: [module: Blank.Fields.Text, searchable: true],
    active: [module: Blank.Fields.Boolean, sortable: true]
  ],
  identity_field: :name,
  order_field: {:name, :asc}
}
```

**Schema with belongs_to and has_many associations:**

```elixir
@derive {
  Blank.Schema,
  fields: [
    title: [module: Blank.Fields.Text, searchable: true],
    author: [module: Blank.Fields.BelongsTo, display_field: :name],
    tags: [module: Blank.Fields.HasMany],
    line_items: [
      module: Blank.Fields.HasMany,
      children: [
        product_name: [label: "Product"],
        quantity: [label: "Qty"]
      ]
    ]
  ],
  identity_field: :title
}
```

**Schema with custom changesets, Currency, Password, and QRCode:**

```elixir
@derive {
  Blank.Schema,
  fields: [
    price: [module: Blank.Fields.Currency, sortable: true],
    password: [module: Blank.Fields.Password, viewable: false],
    barcode: [module: Blank.Fields.QRCode, path: "/items"]
  ],
  create_changeset: &__MODULE__.admin_create_changeset/2,
  update_changeset: &__MODULE__.admin_update_changeset/2
}
```

**Schema with Location field:**

```elixir
@derive {
  Blank.Schema,
  fields: [
    name: [module: Blank.Fields.Text, searchable: true],
    location: [
      module: Blank.Fields.Location,
      address_fun: &MyApp.Geocoder.search/1
    ]
  ],
  identity_field: :name
}
```

**Schema with a custom select expression on an association:**

```elixir
@derive {
  Blank.Schema,
  fields: [
    content: [viewable: false],
    authors: [
      display_field: :full_name,
      searchable: true,
      sortable: true,
      select: quote do
        dynamic([p], fragment("concat(?, ' ', ?)", p.first_name, p.last_name))
      end,
      children: [
        first_name: [],
        last_name: []
      ]
    ]
  ],
  identity_field: :people,
  order_field: :inserted_at
}
```

## Where to next

- [Field Options](./Field%20Options.md) — detailed per-field-type docs
- [AdminPage Options](./AdminPage%20Options.md) — options for `use Blank.AdminPage`
- [Configuration](./Configuration.md) — app-level Blank config keys
