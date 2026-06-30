defmodule Blank.Components.LocationSelectTest do
  use Blank.LiveViewCase

  import Phoenix.LiveViewTest

  alias Blank.Components.LocationSelect
  alias Blank.Field

  defp build_form_field(value) do
    definition = %Field{
      key: :location,
      module: Blank.Fields.Location,
      label: "Location"
    }

    form = Phoenix.Component.to_form(%{"location" => value})

    {form[:location], definition}
  end

  describe "rendering with a Geo.Point value" do
    test "displays the address in the search input" do
      point = %Geo.Point{
        coordinates: {-122.4194, 37.7749},
        properties: %{"address" => "San Francisco, CA"}
      }

      {field, definition} = build_form_field(point)

      html =
        render_component(LocationSelect, %{
          id: "test-location",
          field: field,
          definition: definition,
          search_fun: fn _query -> [] end
        })

      assert html =~ "San Francisco, CA"
      assert html =~ "Longitude"
      assert html =~ "Latitude"
    end
  end

  describe "rendering with a map value" do
    test "displays the address in the search input" do
      value = %{
        "coordinates" => [-74.0, 40.0],
        "properties" => %{"address" => "123 Main St"}
      }

      {field, definition} = build_form_field(value)

      html =
        render_component(LocationSelect, %{
          id: "test-location-map",
          field: field,
          definition: definition,
          search_fun: fn _query -> [] end
        })

      assert html =~ "123 Main St"
      assert html =~ "Longitude"
      assert html =~ "Latitude"
    end
  end

  describe "rendering with a Geo.Point and search_fun" do
    test "renders successfully with an initial value" do
      point = %Geo.Point{
        coordinates: {-122.4194, 37.7749},
        properties: %{"address" => "San Francisco, CA"}
      }

      {field, definition} = build_form_field(point)

      search_fun = fn _query ->
        [
          %Geo.Point{
            coordinates: {-122.4194, 37.7749},
            properties: %{"address" => "San Francisco, CA"}
          }
        ]
      end

      html =
        render_component(LocationSelect, %{
          id: "test-location-search",
          field: field,
          definition: definition,
          search_fun: search_fun
        })

      assert html =~ "San Francisco, CA"
      assert html =~ "search_input"
    end
  end
end
