defmodule Blank.Exporters do
  @moduledoc """
  The list of enabled exporters.
  """

  @exporters [
    Blank.Exporters.QRCode,
    Blank.Exporters.CSV
  ]

  @doc """
  Returns the enabled exporters

  To add additional exporters you need to add them as a list to your application
  config by setting the `:additional_exporters` option to a list of custom
  exporters.

      config :blank,
        ...
        additional_exporters: [MyApp.CustomExporter]
        ...
  """
  @spec exporters() :: [atom()]
  def exporters do
    @exporters ++ Application.get_env(:blank, :additional_exporters, [])
  end
end
