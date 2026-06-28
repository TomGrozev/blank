# Fold Audit Display into AuditLogComponent

`Blank.Audit.Display` was presentation logic (text, icon, colour for each action type) used only by `Blank.Components.AuditLogComponent`. It was a separate module in the Audit namespace, but it was not an audit concern — it was a rendering concern. Folding it into the component improves locality: the rendering logic lives with the thing that renders it. The functions were renamed (`audit_text/4`, `audit_icon/1`, `audit_colour/1`) to avoid collision with `Blank.Components.icon/1` which is imported via `use Blank.Web`.

## Considered Options

- **Fold into AuditLogComponent** (chosen) — presentation logic lives with the renderer. One fewer module.
- **Keep as Display** — pure functions are easier to unit test in isolation, but the tests would be testing presentation, not audit logic.
