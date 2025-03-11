defmodule Blank.Controllers.ExportController do
  use Blank.Web, :controller

  def download(conn, %{"id" => id}) do
    case Blank.DownloadAgent.get(id) do
      {:ok, path} ->
        send_download(conn, {:file, path})

      {:error, _reason} ->
        send_resp(conn, 404, "404 - not found")
    end
  end
end
