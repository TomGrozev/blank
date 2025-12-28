defmodule Blank.Fields.Currency do
  @moduledoc """
  Renders currency text
  """

  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <span>
      ${:io_lib.format("~.2f", [@value || 0.0]) |> to_string()}
    </span>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input
        field={@field}
        type="number"
        label={@definition.label}
        disabled={@definition.readonly}
        prefix_icon="hero-banknotes"
      />
    </div>
    """
  end
end
