defmodule Blank.Controllers.ExportController do
  @moduledoc false
  use Blank.Web, :controller

  @doc """
  Downloads a download with id

  Takes a parameter of `id` and fetches the pre-prepared download. If the
  download doesn't exist 404 will be returned.
  """
  @spec download(conn :: Plug.Conn.t(), map()) :: Plug.Conn.t()
  def download(conn, %{"id" => id}) do
    case Blank.DownloadAgent.get(id) do
      {:ok, path} ->
        send_download(conn, {:file, path})

      {:error, _reason} ->
        send_resp(conn, 404, "404 - not found")
    end
  end

  @doc """
  Downloads a QR code

  Takes a parameter of `code` and `path` and generates a png QR code which is
  then downloaded.
  """
  @spec qr_code(conn :: Plug.Conn.t(), map()) :: Plug.Conn.t()
  def qr_code(conn, %{"code" => code, "path" => path}) do
    png = Blank.Utils.QRCode.png(code, path)

    send_download(conn, {:binary, png}, filename: "#{code}.png")
  end

  def qr_code(conn, _params) do
    send_resp(conn, 404, "404 - not found")
  end
end
