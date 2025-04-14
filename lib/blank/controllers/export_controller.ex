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

  def qr_code(conn, %{"code" => code, "path" => path}) do
    png = Blank.Utils.QRCode.png(code, path)

    send_download(conn, {:binary, png}, filename: "#{code}.png")
  end

  def qr_code(conn, _params) do
    send_resp(conn, 404, "404 - not found")
  end
end
