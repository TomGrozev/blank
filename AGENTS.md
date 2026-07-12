## Agent skills

### Issue tracker

Issues live in GitHub Issues for this repo (`gh` CLI); external pull requests are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical role names are used verbatim: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Documentation

When adding or changing user-visible behaviour, update the relevant guide in `guides/` and add a `CHANGELOG.md` entry. The mapping:

| Change area | Guide to update |
|---|---|
| Authentication, login, ueberauth, bootstrap | `guides/introduction/Authentication.md` |
| Authorization, roles, policy modules, scopes | `guides/introduction/Authorization.md` |
| Role mappers (IdP claim → role) | `guides/introduction/Role Mappers.md` |
| New field type or field option | `guides/cheatsheets/Field Options.md` |
| New AdminPage option or callback | `guides/cheatsheets/AdminPage Options.md` |
| New Schema derive option | `guides/cheatsheets/Schema Options.md` |
| New or changed mix task | `guides/cheatsheets/Mix Tasks.md` |
| New config key | `guides/cheatsheets/Configuration.md` |
| Export behaviour or new exporter | `guides/howtos/Custom Exporter.md` |
| Stats behaviour | `guides/howtos/Custom Stats.md` |
| Audit logging | `guides/howtos/Audit Logging.md` |
| Routing (blank_admin, admin_page) | `guides/howtos/Routing.md` |
| Quick-start flow changes | `README.md` and `guides/introduction/Getting Started.md` |

Also update `mix.exs` `extras` list when adding new guide files.