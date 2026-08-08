# Import

Blank ships a built-in import feature that lets you bulk-insert records from a CSV file. It uses a two-step interactive flow — upload and parse, then map fields — and runs every insert inside a single database transaction so invalid rows roll back atomically.

## Overview

The import feature is wired into every Admin Page by default. When an Admin clicks the "Import" button on the index page, a modal opens with two stages:

1. **Upload & Parse** — drag or select a CSV file. Blank parses it and shows a sample of the first five rows.
2. **Field Mapping** — for each schema field, pick which CSV column maps to it. Optionally configure splitter regexes for complex cell values. Blank previews the mapped data live as you configure. Click "Import rows" to commit.

Every row is validated through the schema's changeset function. The entire batch runs inside an `Ecto.Multi` transaction — if any row fails validation, nothing is inserted. Successful imports emit an audit event under `{resource_type}.create_multiple`.

## The import button

Every Admin Page gets an import button in the index page's action bar by default:

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  use Blank.AdminPage,
    schema: MyApp.Products.Product
end
```

This generates a route at `#{your_admin_path}/products/import` and renders the `Blank.Components.ImportComponent` in a modal.

### Disabling the import button

To hide the import button, set `import: nil` in the `:index_buttons` option:

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  use Blank.AdminPage,
    schema: MyApp.Products.Product,
    index_buttons: [import: nil]
end
```

### Customising the button appearance

You can change the button's icon, text, and variant:

```elixir
defmodule MyAppWeb.Admin.ProductsLive do
  use Blank.AdminPage,
    schema: MyApp.Products.Product,
    index_buttons: [
      import: [
        text: "Upload CSV",
        icon: "hero-cloud-arrow-up",
        variant: "primary"
      ]
    ]
end
```

The `text` field supports `{name}` and `{plural_name}` template values. For all available button options, see the `index_buttons` section in the `Blank.AdminPage` moduledoc.

## The CSV format

Blank expects a CSV file with a **header row** and data rows. Each header name becomes a selectable column in the field mapping step.

```csv
name,email,status
John Doe,john@example.com,active
Jane Smith,jane@example.com,active
Robert Johnson,bob@example.com,inactive
```

### Requirements

- **Headers are required.** The first row must be column names. Rows with all-empty values are skipped.
- **Encoding:** UTF-8.
- **Delimiter:** comma (`,`). Blank uses the `CSV` library's default settings.
- **Quoting:** standard CSV quoting is supported — wrap values containing commas or newlines in double quotes.

## Field mapping

After uploading and parsing the CSV, Blank shows a mapping table. For each schema field (using the page's `edit_fields`), you select which CSV column maps to it.

### Basic mapping

Each schema field has a dropdown listing all CSV column headers. Select a header to map that field:

```
Model field →  CSV field       Splitter regex  Value splitter regex  Field order
Name        →  name            [None]          [None]                [—]
Email       →  email           [None]          [None]                [—]
Status      →  status          [None]          [None]                [—]
```

Blank previews the mapped data in the sample table below the mapping form. As you change mappings, the preview updates live.

### Splitting cell values

If a CSV cell contains multiple values you want to split into separate records, use the **Splitter regex** field. For example, if the `tags` column contains `"elixir,erlang,phoenix"`, you can split it:

```
Model field →  CSV field       Splitter regex  Value splitter regex  Field order
Tags        →  tags            ,\s*            [None]                [—]
```

The value splitter regex applies a second split on each value from the first split. Both accept any valid Elixir regex pattern (compiled with `Regex.compile!/2` with `"i"` flag).

### Field order (nested structures)

For fields with nested children (declared via `:children` in the schema's field definition), the **Field order** dropdown lets you specify how split values map to child keys. Choose a permutation of the child keys.

## How data is processed

When you click "Import rows", Blank:

1. Applies the field mappings and splitter regexes to every CSV row.
2. Builds a parameter map for each row using the changeset types of the mapped fields.
3. Calls `Blank.Context.create_multiple/4`, which wraps all row inserts in a single `Ecto.Multi` transaction.
4. Each row is validated via `Blank.Context.change(item, :new, attrs)`, which calls your schema's changeset function (the `Blank.Schema` `changeset/2` callback).

The entire batch succeeds or fails atomically. If one row is invalid, nothing is committed.

### Result handling

After the transaction:

- **All rows succeed** — flash message: *"Imported {count} rows"*, modal closes.
- **Partial success** — flash message: *"Failed to import {plural_name}, inserted ({count}/{total})"*, modal closes.
- **Validation failure** — flash message: *"Failed to import {plural_name}"*, modal stays open with validation errors.

## Validation

Since each row goes through your schema's `changeset/2` callback with action `:new`, any validations you've defined there apply automatically:

```elixir
# In your Ecto schema module
def changeset(item, attrs) do
  item
  |> cast(attrs, [:name, :email, :status])
  |> validate_required([:name, :email])
  |> unique_constraint(:email)
end
```

Columns that are not mapped are simply omitted from the parameter map passed to the changeset, so they will not trigger required-field validations unless the field is missing in the CSV.

### Customising import validation

If you need different validation rules for imports versus regular form creation, you can pattern-match on the action inside your changeset function:

```elixir
def changeset(item, :new, attrs) when action == :new do
  # Standard creation validations
  item
  |> cast(attrs, [:name, :email, :status])
  |> validate_required([:name, :email])
end
```

However, `create_multiple/4` always calls `change(item, :new, attrs)`, so the `:new` action is what you get for both form creates and imports. If you need import-specific validation, see the next section.

### Accessing the import action

The import uses the `:new` action for changesets. If you need to distinguish imports from regular creates, you can use a custom changeset function that checks for import-specific fields or add a virtual field to signal the import context.

## Audit logging

Every import operation emits an audit event with the action `{resource_type}.create_multiple`. For example, importing into a `Product` schema produces `"products.create_multiple"`.

The audit entry captures:

| Field | Value |
|---|---|
| `action` | `"products.create_multiple"` |
| `params` | `%{item_ids: ["id1", "id2", ...]}` — the IDs of all created records |
| `user` | The acting Admin |
| `ip_address` | The Admin's IP address |
| `actor_display_name` and `actor_email` | Snapshot of the Admin's identity |

This entry is viewable in the [audit log viewer](Audit%20Logging.md#the-audit-log-viewer) at `/admin/audit`.

Because the audit step is inside the same `Ecto.Multi` transaction, an audit entry is only written if the import succeeds.

## Complete example

Here is an Admin Page configured for importing users from a CSV:

```elixir
defmodule MyAppWeb.Admin.UsersLive do
  use Blank.AdminPage,
    schema: MyApp.Accounts.User,
    index_buttons: [
      import: [
        text: "Upload User CSV",
        variant: "primary"
      ]
    ]

  # Validations in the schema module apply automatically:
  #
  # def changeset(user, attrs) do
  #   user
  #   |> cast(attrs, [:name, :email, :role])
  #   |> validate_required([:name, :email])
  #   |> unique_constraint(:email)
  # end
end
```

And the corresponding CSV file:

```csv
name,email,role
Alice Chen,alice@example.com,member
Bob Patel,bob@example.com,manager
Carol Nguyen,carol@example.com,member
```

After uploading, map the three columns to `name`, `email`, and `role`, then click "Import rows". Each row is validated through the `User` schema's changeset — duplicate emails are caught by the `unique_constraint`, and missing names or emails are caught by `validate_required`.

## Where to next

- **Audit Logging** — learn how to query and view audit events, including import entries. See the [Audit Logging guide](Audit%20Logging.md).
- **Custom Field** — if your CSV contains complex data types (e.g. nested JSON, association data), create a custom Field to handle the rendering. See the [Custom Field guide](Custom%20Field.md).
- **Custom Exporter** — write an Exporter to complement the import feature with custom export formats. See the [Custom Exporter guide](Custom%20Exporter.md).
- **`Blank.AdminPage`** — moduledoc for the full list of options including `index_buttons`, `edit_fields`, and `stats`.
