# Changelog

## Unreleased

### Fixed

- Blank now compiles against Flop 0.29 and flop_phoenix 0.27 ([#37](https://github.com/TomGrozev/blank/issues/37)). The `Blank.Schema` derive now does what `use Flop.Schema` does (it sets `@flop_options` and lets Flop generate `__flop_schema__/0`), instead of generating a `Flop.Schema` protocol implementation.
- Flop must resolve to `~> 0.29` and flop_phoenix to `~> 0.27`.
- A schema that derives `Blank.Schema` no longer needs `use Flop.Schema`.
- Flop 0.29 removed the per-option helpers (`Flop.Schema.filterable/1`, `sortable/1`, `max_limit/1`, `default_limit/1`, `default_order/1`, `pagination_types/1`, `default_pagination_type/1`). Code that called them must use `Flop.Schema.field_info/2`, `Flop.Schema.get_field/3`, or `Flop.Schema.flop_schema!/1` instead.
- Column-header sorting on the index page now takes effect. Flop owns the query ordering, and Blank passes `:order_field` to Flop as its `default_order`.
- Search now skips columns that do not accept a pattern match (such as `:binary_id`, `:binary`, integer, or boolean) in the simple search box and uses an exact match (`:==`) for them in advanced search. The mode toggle is hidden when the schema has no text-searchable column.

## 0.1.0

Initial release of Blank — a drop-in admin panel for Elixir projects.

### Shipped features

- **CRUD admin panels** — Automatic index, show, create, and edit pages for your Ecto schemas
- **Filtering & search** — Advanced search and filter on any field
- **Audit logging** — Track every mutation with automatic audit trails
- **CSV import** — Bulk import data from CSV files with automatic validation
- **CSV & QR code exports** — Built-in exporters with a behaviour for custom exports
- **Role-based authorization** — Pluggable role system with policy modules and scopes
- **Ueberauth integration** — Plug-and-play authentication via ueberauth providers
- **10+ field types** — Text, Boolean, DateTime, Password, Currency, QRCode, Location, and more
- **Statistics dashboard** — Summary statistics on admin index pages
- **Multi-database support** — Works with PostgreSQL and ArangoDB out of the box
