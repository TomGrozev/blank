defmodule Blank.Utils.QRCode do
  @spec svg(String.t()) :: String.t()
  def svg(code) do
    generate(code)
    |> EQRCode.svg()
  end

  @spec png(String.t()) :: String.t()
  def png(code) do
    generate(code)
    |> EQRCode.png()
  end

  defp generate(code) do
    base_url = get_base_url()

    URI.append_query(URI.parse(base_url), URI.encode_query(%{"code" => code}))
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
