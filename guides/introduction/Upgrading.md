# Upgrading

How to upgrade Blank between versions. This guide documents breaking changes, migration steps, and config updates.

## Version Policy

Blank follows [semantic versioning](https://semver.org/) (SemVer):

- **Patch releases** (`0.1.x`) — bug fixes and small improvements; backwards-compatible. You can upgrade safely.
- **Minor releases** (`0.x.0`) — new features; may include breaking changes. Breaking changes are documented in the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md) and in the version-specific section below.
- **Major releases** (`x.0.0`) — significant breaking changes. Expect to follow a migration guide.

During the `0.x` phase, breaking changes may appear in minor releases as the API stabilizes toward 1.0.

## Checking Your Version

Run these commands to see which version of Blank you're on:

```bash
# Installed version
mix deps | grep blank

# Exact locked version (in mix.lock)
grep ":blank" mix.lock
```

## Upgrading to 0.1.0

### Initial Release

If you're starting fresh with Blank, follow the [Getting Started](Getting%20Started.md) guide. There are no upgrade steps for new installs.

### From Pre-0.1.0

Blank was previously a private/internal project. If you were using an earlier version before the public 0.1.0 release:

1. **Update your dependency** in `mix.exs`:

   ```elixir
   {:blank, "~> 0.1.0"}
   ```

2. **Fetch the new version:**

   ```bash
   mix deps.get
   ```

3. **Re-run the install task** to copy any new or changed migrations:

   ```bash
   mix blank.install
   ```

4. **Run migrations:**

   ```bash
   mix ecto.migrate
   ```

5. **Check the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md)** for any breaking changes or config updates specific to 0.1.0.

## Common Upgrade Issues

### Migration Conflicts

Blank copies its migrations into your app's `priv/repo/migrations` during `mix blank.install`. If you've modified Blank's migrations, upgrading may produce conflicts.

**Best practice:** Keep Blank's migrations untouched. Add your own schema changes in separate migrations that run after Blank's. This avoids conflicts when re-running `mix blank.install`.

If you do need to resolve a conflict, compare your local migrations against Blank's originals and merge changes manually. Pay attention to migration timestamps — Blank's install task generates new timestamps for each run.

### Config Changes

Between versions, Blank may introduce new config keys or deprecate existing ones. After upgrading:

- Check the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md) for any config changes.
- Review the [Configuration](guides/cheatsheets/Configuration.md) cheatsheet for the full list of available options.
- Compare your `config :blank` block against the current defaults.

### Callback Changes

If your app implements custom AdminPage callbacks (e.g., `c:Blank.AdminPage.before_save/2`, `c:Blank.AdminPage.custom_actions/1`), the function signatures may change between versions. Check the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md) and the [AdminPage Options](guides/cheatsheets/AdminPage%20Options.md) cheatsheet for up-to-date signatures.

### Compile Errors After Upgrade

If your app fails to compile after upgrading:

1. Run `mix deps.clean blank` to remove old compiled artifacts.
2. Run `mix deps.get` and `mix deps.compile blank` to rebuild.
3. Check the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md) for removed modules or renamed functions.

## Getting Help

- Check the [CHANGELOG](https://github.com/TomGrozev/blank/blob/main/CHANGELOG.md) for version-specific notes.
- Check the [Troubleshooting](Troubleshooting.md) guide for common issues.
- Open a [GitHub issue](https://github.com/TomGrozev/blank/issues) if you encounter a problem not covered here.
