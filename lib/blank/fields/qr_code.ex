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

    qr_path =
      socket.router.__blank_prefix__()
      |> URI.parse()
      |> URI.append_path("/qrcode")
      |> URI.append_query(URI.encode_query(%{code: value, path: path}))
      |> URI.to_string()

    download_path =
      Phoenix.VerifiedRoutes.unverified_path(socket, socket.router, qr_path)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:qr_code, Blank.Utils.QRCode.svg(value, path))
     |> assign(:download_path, download_path)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Blank.Field
  def render_list(assigns) do
    ~H"""
    <div>
      <span>{@value}</span>
    </div>
    """
  end

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="inline-flex flex-col items-center justify-center space-y-4 p-4 bg-gray-100 dark:bg-gray-800 shadow rounded-xl">
        <div class="rounded-lg overflow-hidden inline-block bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
          {raw(@qr_code)}
        </div>
        <span class="text-gray-900 dark:text-white font-bold text-xl">{@value}</span>
        <.link href={@download_path} target="_blank">
          <.button>
            <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
            Download
          </.button>
        </.link>
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
