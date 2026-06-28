# Extract JS utilities and field rendering from Components

`Blank.Components` was a 1045-line grab-bag containing UI primitives, form components, field rendering, stats, and JS utilities. The standard Phoenix pattern is to keep everything in one `CoreComponents` module, but Blank's `Components` module mixed three different kinds of things: function components (returning rendered templates), JS command builders (returning `Phoenix.LiveView.JS` structs), and domain-specific field rendering (bridging to LiveComponents). UI primitives and form components remain in `Blank.Components`. JS utilities live at `Blank.Components.JS` and field rendering bridges live at `Blank.Components.Field` — both sub-namespaces of the `Components` umbrella, since they are rendering-side concerns that only make sense alongside the components they support. All three are imported via `Blank.Web.html_helpers/0`, so the caller experience is unchanged.

## Considered Options

- **Extract under `Blank.Components.*`** (chosen) — `Blank.Components.JS` for JS commands, `Blank.Components.Field` for domain-specific rendering. Groups all rendering-side concerns under one umbrella. Matches the existing `Blank.Components.{ExportComponent,LocationSelect,SearchableSelect,ImportComponent,AuditLogComponent}` pattern.
- **Extract as top-level `Blank.JS` and `Blank.Field.Components`** — the originally chosen option, now superseded. Clean seams by kind and by domain, but `Blank.JS` as a top-level sibling of `Blank.Components` was misleading: it is a component helper that happens to return `%Phoenix.LiveView.JS{}` structs, not a peer of `Blank.Components`.
- **Don't split** — the grab-bag is the standard Phoenix pattern. Splitting adds modules without concentrating complexity.
