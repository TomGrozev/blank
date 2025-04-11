if Code.ensure_loaded?(Geo) do
  defmodule Blank.Fields.Location do
    @schema [
      address_fun: [
        type: {:fun, 1},
        doc: "a function that takes a search query and returns addresses"
      ]
    ]

    use Blank.Field, schema: @schema

    alias Blank.Components.SearchableSelect

    @impl Blank.Field
    def render_display(assigns) do
      ~H"""
      <div>
        <span>{@value}</span>
      </div>
      """
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
            module={SearchableSelect}
            field={@field}
            label="Address"
            search_fun={&search(@definition.address_fun, &1)}
            value_mapper={&value_mapper/1}
          />
        </div>
        <input type="hidden" name={"#{@field.name}[type]"} value="Point" />
        <input type="hidden" name={"#{@field.name}[properties][address]"} value={@address} />
        <.input
          name={"#{@field.name}[coordinates][]"}
          type="text"
          label="Longitude (DD)"
          value={@lon}
          disabled={@definition.readonly}
        />
        <.input
          name={"#{@field.name}[coordinates][]"}
          type="text"
          label="Latitude (DD)"
          value={@lat}
          disabled={@definition.readonly}
        />
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end

    defp get_lon_lat_addr(%{"coordinates" => [lon, lat], "properties" => %{"address" => address}}),
      do: {lon, lat, address}

    defp get_lon_lat_addr(%Geo.Point{
           coordinates: {lon, lat},
           properties: %{"address" => address}
         }),
         do: {lon, lat, address}

    defp get_lon_lat_addr(_), do: {nil, nil, nil}

    defp search(fun, query) do
      case fun.(query) do
        {:ok, res} -> Enum.map(res, &value_mapper/1)
        _ -> []
      end
    end

    defp value_mapper(%Geo.Point{properties: %{"address" => address}} = item) do
      %{
        label: address,
        value: item
      }
    end

    defp value_mapper(%{"properties" => %{"address" => address}} = item) do
      %{
        label: address,
        value: item
      }
    end
  end
end

if !Code.ensure_loaded?(Geo) do
  defmodule Blank.Fields.Location do
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
