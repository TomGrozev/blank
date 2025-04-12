defmodule Blank.Fields.DateTime do
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
      <.input field={@field} type="datetime-local" label={@definition.label} />
    </div>
    """
  end
end
