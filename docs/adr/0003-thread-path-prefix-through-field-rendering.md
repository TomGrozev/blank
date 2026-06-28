# Thread path_prefix through field rendering instead of router access

`Blank.Fields.QRCode` built download URLs by reaching into `socket.router.__blank_prefix__()` and calling `Phoenix.VerifiedRoutes.unverified_path/4`. This coupled a presentational field module to Phoenix routing internals, making fields non-portable and hard to test without a live socket and router. Instead, `path_prefix` is threaded through the field rendering functions (`field_list/1`, `field_display/1`, `field_form/1`) as an assign, following the same pattern already used for `time_zone`. Fields receive `path_prefix` and build URLs from it directly. `path_prefix` defaults to `"/"` if not present.

## Consequences

All field rendering bridge functions in `Blank.Field.Components` now declare `attr :path_prefix, :string`. Admin page templates pass `path_prefix={@path_prefix}`. New fields that need URL building should read `path_prefix` from assigns, not from the socket router.
