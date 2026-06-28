# Field Options Quick Reference

Quick-reference for the options available on field definitions in `Blank.Schema`.

## Common options

These apply to every field, regardless of which Field adapter is used. See `Blank.Field` for the full documentation.

| Option | Type | Default | Description |
|---|---|---|---|
| `:label` | `String.t()` | humanized field name | Label displayed in list and form views. |
| `:placeholder` | `String.t()` | `nil` | Placeholder text for form inputs. |
| `:module` | `atom()` | auto-detected | Override the Field adapter module (e.g. `Blank.Fields.Password`). |
| `:searchable` | `boolean()` | `false` | Include this field in the advanced search filter. |
| `:sortable` | `boolean()` | `false` | Allow sorting by this field in the index view. |
| `:viewable` | `boolean()` | `true` | Show this field in admin pages. Set to `false` to hide it. |
| `:readonly` | `boolean()` | `false` | Make the field read-only in edit/new forms. |
| `:display_field` | `atom()` | `nil` | For association fields — which field to show as the label. Falls back to the related schema's `identity_field`. |
| `:select` | `DynamicExpr.t()` | `nil` | Custom dynamic select expression loaded with the field query. |

## Association-specific options

### Blank.Fields.BelongsTo

Auto-applied to `belongs_to` associations. Uses `Blank.Components.SearchableSelect` in the form.

| Option | Description |
|---|---|
| `:display_field` | Field on the related schema to show as the selected value. |

### Blank.Fields.HasMany

Auto-applied to `has_many` and `has_one` associations.

| Option | Type | Description |
|---|---|---|
| `:children` | `Keyword.t()` | Sub-field definitions for each child entry. Same shape as the top-level `fields:` option. |

## Type-specific options

### Blank.Fields.QRCode

| Option | Type | Default | Description |
|---|---|---|---|
| `:path` | `String.t()` | `"/"` | Path component appended to the value when generating the QR code URL. |

### Blank.Fields.Location

Requires the optional `:geo` dependency.

| Option | Type | Description |
|---|---|---|
| `:address_fun` | `(String.t() -> {:ok, [map()]})` | 1-arity function for address search. Enables the address picker in forms. |

## Examples

```elixir
@derive {
  Blank.Schema,
  fields: [
    title: [searchable: true, sortable: true],
    price: [module: Blank.Fields.Currency],
    author: [display_field: :full_name, searchable: true],
    tags: [],
    password: [module: Blank.Fields.Password, viewable: false],
    barcode: [module: Blank.Fields.QRCode, path: "/items"],
    location: [
      module: Blank.Fields.Location,
      address_fun: &MyApp.Geocoder.search/1
    ]
  ]
}
```
