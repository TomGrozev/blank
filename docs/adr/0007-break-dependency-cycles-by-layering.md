# Break the dependency cycles by layering the field shape above its field collection module

`mix xref graph --format cycles --fail-above 0` found two cycles in Blank: a 15-module cycle through the schema and field `use` macros, and a 3-module cycle through `Blank.Exporter` and its built-in exporters. Annotations cannot fix this: the gate counts runtime edges too (a `@behaviour` is a runtime edge) and works at file granularity, so every reference between two files closes a cycle. The fix is layering: the shared shape compiles against a module that does not depend on it.

## Decisions

**`Blank.Field` is a leaf.** The struct, the behaviour callbacks and the `use` macro stay in `lib/blank/field.ex`, and that file names no field adapter. The base field option schema lives in `Blank.Field.Options` (`lib/blank/field/options.ex`), a leaf module that both `field.ex` and `lib/blank/schema.ex` read, so the protocol file never reads `Blank.Field`; `field.ex` keeps one runtime-only edge to `Blank.Schema`, the label on its validation error.

**One `Blank.Fields` holds the built-in field list.** The collection module, the list, `__aggregate_field_schemas__/0`, `put_field_module/3` and `new!/2` live in `Blank.Fields` (`lib/blank/fields.ex`), named after the namespace its adapters already use, mirroring `Blank.Exporters` beside `Blank.Exporters.CSV`. The list cannot live in `Blank.Field`: every adapter references `Blank.Field` for the behaviour, its `@impl` callbacks and the struct, so a list of adapters inside `field.ex` would close the cycle the whole split exists to avoid. `new!/2` stays with the list for the same reason — it fills a missing `:module` with `Blank.Fields.Text`, so it names an adapter and cannot sit on the leaf. The struct's `module` default is now `nil`; `Blank.Fields.new!/2` fills it.

**The type-to-adapter mapping is its own leaf.** `module_for_type/1` lives in `Blank.Fields.Type` (`lib/blank/fields/type.ex`). `Blank.Fields.List` resolves its inner array type through it, and `Blank.Fields.List` is an entry in the adapter list, so calling `Blank.Fields` from it would close a two-file cycle; `Blank.Fields.Type` lists no adapter and is called by both `Blank.Fields.put_field_module/3` and `Blank.Fields.List`.

**The schema protocol splits into two files.** The `Blank.Schema` protocol and the internal `Blank.Schema.Options` module live in `lib/blank/schema.ex`; the `defimpl Blank.Schema, for: Any` derive macro lives in `lib/blank/schema/any.ex`. `Options.validate!/3` takes the field-option schemas from its caller, so `Options` never reaches `Blank.Fields`; its base field option schema comes from `Blank.Field.Options`, so the protocol file no longer reads `Blank.Field`.

**The association options query moves to `Blank.Field.Query`.** `Blank.Context.options_query/4` becomes `Blank.Field.Query.options_query/4`. `Blank.Fields.BelongsTo` is its only caller, and calling `Blank.Context` put a field adapter above the audit layer.

**The exporter list moves to `Blank.Exporters`.** The built-in exporter list and `exporters/0` live in `Blank.Exporters` (`lib/blank/exporters.ex`). `Blank.Exporter` listing its own implementers is a cycle, because `@behaviour` is a runtime edge.

## Consequences

Public functions move:

- `Blank.Exporter.exporters/0` → `Blank.Exporters.exporters/0`
- `Blank.Field.new!/2` and `__aggregate_field_schemas__/0` → `Blank.Fields`
- `module_for_type/1` → `Blank.Fields.Type`
- `Blank.Context.options_query/4` → `Blank.Field.Query.options_query/4`

Field options keep the `@derive Blank.Schema` label, and the base field option schema lives in `Blank.Field.Options` so the protocol file no longer reads `Blank.Field`; `Blank.Field` keeps one runtime-only edge to `Blank.Schema` for that label. The precommit xref gate becomes `--fail-above 0`.

## Considered Options

- **Layer the shape above its adapter list** (chosen) — the leaf modules compile without naming their implementers, so no file closes a cycle.
- **Keep `module_for_type/1` on `Blank.Fields` instead of its own leaf** — `Blank.Fields.List` calls the mapping and is listed by the collection module, so the two files would close a cycle.
- **Keep `exporters/0` on `Blank.Exporter` and resolve modules through `Module.concat`** — hides the modules from the compiler, so xref stops seeing the edges instead of the cycle being gone.
- **Inject the options query as a `:search_fun` assign** — rewires every form call site to avoid one static reference.
