# Blank

Blank is a drop-in admin panel for your Elixir projects. Derive `Blank.Schema` on your Ecto schemas, declare admin pages with `use Blank.AdminPage`, and you get CRUD, filtering, audit logging, and exports with minimal configuration.

## Why make Blank?

Whatever project I made, I would always have to make an admin panel and it got
quite annoying remaking the same thing time and time again. So for one project I
decided that I would just make an easy to setup and use admin panel. And that is
where Blank comes in.

## Quick Start

Add the dependency and config:

```elixir
# mix.exs
def deps do
  [
    {:blank, "~> 0.1.0"}
  ]
end
```

```elixir
# config/config.exs
config :blank,
  endpoint: MyApp.Endpoint,
  repo: MyApp.Repo,
  user_module: MyApp.Accounts.User,
  user_table: :users,
  use_local_timezone: true
```

Then run `mix blank.install` and `mix ecto.migrate`. Derive `Blank.Schema` on your Ecto schemas, set up routing with `blank_admin` and `admin_page`, and create an admin page module with `use Blank.AdminPage`.

See the [HexDocs](https://hexdocs.pm/blank) for the full installation walkthrough.

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/blank).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to Blank.

## License

See [LICENSE](LICENSE) for details.
