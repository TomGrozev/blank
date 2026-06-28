defmodule Blank.Fields.DateTime do
  @moduledoc """
  DateTime field with timezone-aware display.

  In display mode the value is shifted to the Admin's local timezone (set via
  the `@time_zone` assign during mount) and formatted as
  `"%Y-%m-%d %I:%M %p %Z"`. When `use_local_timezone` is disabled in the app
  config, `"Etc/UTC"` is used as the default.

  The form renders as a `datetime-local` input.

  ## Example

      fields: [
        inserted_at: [],
        published_at: [label: "Published at"]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    format = "%Y-%m-%d %I:%M %p %Z"

    datetime = DateTime.shift_zone!(assigns.value, assigns.time_zone, Tz.TimeZoneDatabase)

    assigns = assign(assigns, :value, Calendar.strftime(datetime, format))

    ~H"""
    <span>
      {@value}
    </span>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input
        field={@field}
        type="datetime-local"
        label={@definition.label}
        disabled={@definition.readonly}
      />
    </div>
    """
  end
end
