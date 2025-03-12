defmodule Blank.Fields.QRCode do
  @schema [
    path: [
      type: :string,
      doc: "The path from the base url for the code to be applied to"
    ]
  ]

  use Blank.Field, schema: @schema

  @impl Phoenix.LiveComponent
  def update(%{value: value} = assigns, socket) do
    path = Map.get(assigns.definition, :path, "/")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:qr_code, Blank.Utils.QRCode.svg(value, path))}
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
