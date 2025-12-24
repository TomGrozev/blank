defmodule Blank.Components.ExportComponent do
  @moduledoc false
  use Blank.Web, :live_component

  alias Blank.Exporter

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Export {@plural_name}
        <:subtitle>
          Choose how you want to export the {@plural_name}.
        </:subtitle>
      </.header>

      <div class="grid grid-flow-col grid-cols-3 gap-4 my-8">
        <.button
          :for={exporter <- @exporters}
          phx-click="export"
          phx-value-exporter={exporter}
          phx-target={@myself}
          phx-disable-with="Generating..."
        >
          <.icon
            :if={function_exported?(exporter, :icon, 0)}
            name={apply(exporter, :icon, [])}
            class="w-5 h-5"
          /> Export {apply(exporter, :name, [])}
        </.button>
      </div>

      <.download_modal :if={@download} download={@download} return={@patch} myself={@myself} />
    </div>
    """
  end

  defp download_modal(assigns) do
    ~H"""
    <.modal id="export-confirm-modal" show on_cancel={JS.push("delete-download", target: @myself)}>
      <div class="sm:flex sm:items-start">
        <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 sm:mx-0 sm:h-10 sm:w-10">
          <.icon name="hero-arrow-down-tray" class="h-6 w-6 text-blue-600" />
        </div>
        <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left">
          <h3 class="text-base font-semibold leading-6" id="modal-title">
            Your download is ready!
          </h3>
          <div class="mt-2">
            <p class="text-sm text-base-content/40">
              Your download has been generated and can now be downloaded.
              Click Download to get your export file.
            </p>
          </div>
        </div>
      </div>
      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse sm:space-x-4
          sm:space-x-reverse">
        <.link href={elem(@download, 1)} target="_blank">
          <.button variant="primary" phx-click={JS.navigate(@return)}>Download</.button>
        </.link>
        <.button phx-click={JS.exec("data-cancel", to: "#export-confirm-modal")}>
          Cancel
        </.button>
      </div>
    </.modal>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:download, nil)
     |> assign(:exporters, get_exporters(assigns.fields))}
  end

  defp get_exporters(fields) do
    Blank.Exporter.exporters()
    |> Enum.filter(fn mod ->
      apply(mod, :display?, [fields])
    end)
  end

  @impl true
  def handle_event("delete-download", _params, socket) do
    if download = socket.assigns.download do
      Blank.DownloadAgent.delete(elem(download, 0))
    end

    {:noreply, assign(socket, :download, nil)}
  end

  def handle_event("export", %{"exporter" => exporter}, socket) do
    %{repo: repo, schema: schema, fields: fields} = socket.assigns

    case Exporter.export(exporter, repo, schema, fields) do
      {:ok, id} ->
        prefix = socket.router.__blank_prefix__()

        uri =
          Path.join(prefix, "download")
          |> URI.new!()
          |> URI.append_query("id=#{id}")
          |> URI.to_string()

        {:noreply,
         socket
         |> assign(:download, {id, uri})}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to export")}
    end
  end
end
