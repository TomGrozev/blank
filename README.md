![Blank](priv/static/images/blank.png)

# Blank

[![Hex.pm](https://img.shields.io/hexpm/v/blank.svg)](https://hex.pm/packages/blank)
[![License](https://img.shields.io/hexpm/l/blank.svg)](https://github.com/TomGrozev/blank/blob/main/LICENSE)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/blank)

Blank is a drop-in admin panel for your Elixir projects. Derive `Blank.Schema` on your Ecto schemas, declare admin pages with `use Blank.AdminPage`, and you get CRUD, filtering, audit logging, imports, exports, and role-based authorization with minimal configuration.

## Features

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

## Quick Start

**1.** Add the dependency:

```elixir
# mix.exs
def deps do
  [
    {:blank, "~> 0.1.0"}
  ]
end
```

**2.** Configure Blank:

```elixir
# config/config.exs
config :blank,
  endpoint: MyApp.Endpoint,
  repo: MyApp.Repo,
  user_module: MyApp.Accounts.User,
  user_table: :users,
  use_local_timezone: true
```

**3.** Install and set up your first admin page:

```bash
mix blank.install
mix ecto.migrate
```

Derive `Blank.Schema` on your Ecto schemas, set up routing with `blank_admin` and `admin_page`, and create an admin page module with `use Blank.AdminPage`. You now have a full CRUD admin panel at `/admin/products`.

> See the [Authentication guide](https://hexdocs.pm/blank/Authentication.html) for ueberauth provider setup.

## Why make Blank?

Whatever project I made, I would always have to make an admin panel and it got
quite annoying remaking the same thing time and time again. So for one project I
decided that I would just make an easy to setup and use admin panel. And that is
where Blank comes in.

## Examples

Check out the [demo app](examples/demo_app/) for a working example with two admin pages (Users and Orders), custom stats, authorization policies, and ueberauth integration.

### Screenshots

| Admin index | Edit page | Audit log |
|-------------|-----------|-----------|
| ![Admin index](docs/screenshots/index.png) | ![Edit page](docs/screenshots/edit.png) | ![Audit log](docs/screenshots/audit.png) |

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/blank).

- [Getting Started](https://hexdocs.pm/blank/GettingStarted.html)
- [Authentication](https://hexdocs.pm/blank/Authentication.html)
- [Authorization](https://hexdocs.pm/blank/Authorization.html)
- [Field Options](https://hexdocs.pm/blank/FieldOptions.html)
- [Configuration](https://hexdocs.pm/blank/Configuration.html)
- [Custom Exporter](https://hexdocs.pm/blank/CustomExporter.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to Blank.

## License

See [LICENSE](LICENSE) for details.
