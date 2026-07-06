# Emergency Bootstrap Procedure

## Trust Model Preamble

- Shell access IS the trust perimeter. Anyone with shell access already has more power than the application can grant.
- The break-glass act is **temporarily enabling the `local_login` gate** — NOT a perpetually-present environment variable or hook.
- The deliberately-armed credential in this procedure is the temporarily-enabled local login configuration.

## Step-by-Step Procedure

1. **SSH to the host** running the Blank application.

2. **Temporarily enable local login** in the app's runtime config (e.g. `runtime.exs` or equivalent):
   ```elixir
   config :blank, :auth, local_login: :enabled
   ```
   (Note: the exact config key may vary by deployment — consult your runtime configuration.)

3. **Restart the application** so the boot-time misconfiguration guard re-evaluates with local login enabled.

4. **Create the emergency admin user** using the mix task:
   ```
   mix blank.user.new --email <emergency-admin-email> --password <strong-password> --name <name> --roles system_admin
   ```
   - Required flags: `--email`, `--password`
   - Optional flags: `--name`, `--roles` (comma-separated for multiple roles)
   - The `--provider` and `--external_uid` flags are **not exposed** — the bootstrap user is always a local-identity user.

5. **Recover the IdP** / restore upstream identity provider connectivity.

6. **Revert the config** — set `local_login` back to `:disabled` (or remove the override) in the runtime config.

7. **Restart the application** again to apply the reverted configuration.

## Post-Bootstrap Notes

### Bootstrap User Persistence

The bootstrap User row **survives the config revert**. The `local_login` gate controls whether new logins via the local form are accepted — it does not delete existing local-identity rows. **Operators must clean up the bootstrap user themselves** once long-term admin access is restored via the IdP.

### Durable Audit Record

Each `mix blank.user.new` run emits an `accounts.user_created` audit entry (with `%{email: ..., roles: ...}`) that **survives the config revert**, providing a durable bootstrap record.

## Important Reminders

- This procedure is for **emergency use only** when the IdP is unreachable.
- Shell access is the trust perimeter — this procedure does not weaken that model.
- The break-glass act is opening the `local_login` gate, not maintaining a permanent backdoor.
