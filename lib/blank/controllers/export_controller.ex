defmodule Blank.Controllers.ExportController do
  @moduledoc false
  use Blank.Web, :controller

  alias Blank.Utils.QRCode

  @doc """
  Downloads a download with id

  Takes a parameter of `id` and fetches the pre-prepared download. If the
  download doesn't exist 404 will be returned. If the path is outside the
  expected directory 403 will be returned.
  """
  @spec download(conn :: Plug.Conn.t(), map()) :: Plug.Conn.t()
  # sobelow_skip ["Traversal.SendDownload"]
  # Path is validated against System.tmp_dir()/blank/ before use
  def download(conn, %{"id" => id}) do
    case Blank.DownloadAgent.get(id) do
      {:ok, path} ->
        expected_dir = Path.join(System.tmp_dir!(), "blank")

        if String.starts_with?(Path.expand(path), Path.expand(expected_dir)) do
          send_download(conn, {:file, path})
        else
          send_resp(conn, 403, "403 - forbidden")
        end

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
    png = QRCode.png(code, path)

    send_download(conn, {:binary, png}, filename: "#{code}.png")
  end

  def qr_code(conn, _params) do
    send_resp(conn, 404, "404 - not found")
  end
end
