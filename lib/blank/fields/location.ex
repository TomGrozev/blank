if Code.ensure_loaded?(Geo) do
  defmodule Blank.Fields.Location do
    @moduledoc """
    Geo-location field for storing coordinates and addresses.

    Requires the optional `:geo` dependency. Renders coordinates with
    cardinal-direction formatting (e.g. `33.8688 N, 151.2093 E`) and
    displays the address when available.

    ## Schema options

      * `:address_fun` — a 1-arity function that receives a search query string
        and returns `{:ok, [addresses]}`. When provided, a searchable address
        picker is rendered in the form.

    The underlying value is expected to be a `Geo.Point` struct (or a map with
    `"coordinates"` and `"properties"` keys).

    ## Example

        fields: [
          location: [
            address_fun: &MyApp.Geocoder.search/1
          ]
        ]

    See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
    `:readonly`, `:label`, `:placeholder`, etc.).
    """

    @schema [
      address_fun: [
        type: {:fun, 1},
        doc: "a function that takes a search query and returns addresses"
      ]
    ]

    use Blank.Field, schema: @schema

    alias Blank.Components.LocationSelect

    @impl Blank.Field
    def render_list(assigns) do
      ~H"""
      <div>
        <span>{format_coordinates(@value)}</span>
      </div>
      """
    end

    @impl Blank.Field
    def render_display(assigns) do
      ~H"""
      <div>
        <div :if={@value} class="flex flex-col space-y-4">
          <div>
            <span class="text-xl font-bold p-2 rounded-lg bg-gray-700">
              {format_coordinates(@value, false)}
            </span>
          </div>
          <span :if={Map.has_key?(@value.properties, "address")}>
            <strong>Address: </strong>{address(@value)}
          </span>
        </div>
      </div>
      """
    end

    defp address(%{properties: %{"address" => address}}), do: address
    defp address(_), do: nil

    defp format_coordinates(%{coordinates: {lon, lat}}, trunc \\ true) do
      [
        format_float(lat, trunc),
        " ",
        sign(:lat, lat),
        ", ",
        format_float(lon, trunc),
        " ",
        sign(:lon, lon)
      ]
      |> IO.iodata_to_binary()
    end

    defp sign(:lat, val) when val > 0, do: ?N
    defp sign(:lat, _val), do: ?S
    defp sign(:lon, val) when val > 0, do: ?E
    defp sign(:lon, _val), do: ?W

    defp format_float(float, trunc) do
      val =
        float
        |> abs()
        |> Decimal.from_float()

      if trunc do
        Decimal.round(val, 2)
      else
        val
      end
      |> Decimal.to_string()
    end

    @impl Blank.Field
    def render_form(%{field: field} = assigns) do
      {lon, lat, address} = get_lon_lat_addr(assigns.field.value)

      errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

      assigns =
        assign(assigns, lon: lon, lat: lat, address: address)
        |> assign(:errors, Enum.map(errors, &translate_error(&1)))

      ~H"""
      <div class="grid grid-cols-2 gap-4">
        <div :if={not is_nil(@definition.address_fun)} class="col-span-2">
          <.live_component
            id={"#{@field.id}_searchable_select"}
            module={LocationSelect}
            field={@field}
            definition={@definition}
            label="Address"
            search_fun={&search(@definition.address_fun, &1)}
          />
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end

    defp get_lon_lat_addr(%{
           "coordinates" => [lon, lat],
           "properties" => %{"address" => address}
         }),
         do: {lon, lat, address}

    defp get_lon_lat_addr(%Geo.Point{
           coordinates: {lon, lat},
           properties: %{"address" => address}
         }),
         do: {lon, lat, address}

    defp get_lon_lat_addr(_), do: {nil, nil, nil}

    defp search(fun, query) do
      case fun.(query) do
        {:ok, res} -> res
        _ -> []
      end
    end
  end
end

if !Code.ensure_loaded?(Geo) do
  defmodule Blank.Fields.Location do
    @moduledoc """
    Fallback location field when the `:geo` dependency is not installed.

    Both display and form views show a "GEO DEPENDENCY NOT INSTALLED" message.
    Add `{:geo, "~> 3.6"}` to your deps to enable full location support.
    """

    use Blank.Field

    @impl Blank.Field
    def render_display(assigns) do
      ~H"""
      <span>GEO DEPENDENCY NOT INSTALLED</span>
      """
    end

    @impl Blank.Field
    def render_form(assigns) do
      ~H"""
      <span>GEO DEPENDENCY NOT INSTALLED</span>
      """
    end
  end
end
