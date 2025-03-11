defmodule Blank.Fields.Boolean do
  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <div>
      <.icon :if={@value} name="hero-check-circle" class="w-5 h-5 text-green-500" />
      <.icon :if={!@value} name="hero-x-circle" class="w-5 h-5 text-rose-500" />
    </div>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input
        field={@field}
        type="checkbox"
        label={@definition.label}
        disabled={@definition.readonly}
      />
    </div>
    """
  end
end
