defmodule Blank.Fields.QRCode do
  use Blank.Field

  @impl Phoenix.LiveComponent
  def update(%{value: value} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:qr_code, Blank.Utils.QRCode.svg(value))}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <div>
      <span>{@value}</span>
      <div>
        <div class="mt-4 rounded-lg overflow-hidden inline-block">
          {raw(@qr_code)}
        </div>
      </div>
    </div>
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
