defmodule Blank.Utils.QRCode do
  @spec svg(String.t()) :: String.t()
  def svg(code, path \\ "/") do
    generate(code, path)
    |> EQRCode.svg(
      background_color: :transparent,
      color: "currentColor"
    )
  end

  @spec png(String.t()) :: String.t()
  def png(code, path \\ "/") do
    generate(code, path)
    |> EQRCode.png()
  end

  defp generate(code, path) do
    base_url = get_base_url()

    base_url
    |> Path.join(path)
    |> URI.parse()
    |> URI.append_query(URI.encode_query(%{"code" => code}))
    |> URI.to_string()
    |> EQRCode.encode()
  end

  defp get_base_url do
    case Application.get_env(:blank, :endpoint) do
      nil ->
        raise RuntimeError, "you must set the :endpoint config option to use the
          qr code field"

      endpoint ->
        if !(is_atom(endpoint) and function_exported?(endpoint, :url, 0)) do
          raise ArgumentError, ":endpoint provided is not a Phoenix Endpoint"
        end

        endpoint.url()
    end
  end
end
