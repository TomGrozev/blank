defmodule Blank.Fields.Text do
  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
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
      <.input field={@field} type="text" label={@definition.label} disabled={@definition.readonly} />
    </div>
    """
  end
end
