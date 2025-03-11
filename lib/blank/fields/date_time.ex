defmodule Blank.Fields.DateTime do
  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    format = "%Y-%m-%d %I:%M %p UTC"

    assigns = assign(assigns, :value, Calendar.strftime(assigns.value, format))

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
