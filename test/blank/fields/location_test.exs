defmodule Blank.Fields.LocationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with Geo.Point value returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location"
      }

      value = %Geo.Point{
        coordinates: {-74.0, 40.0},
        properties: %{"address" => "123 Main St"}
      }

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :display,
          field: definition,
          value: value
        })

      assert html =~ "123 Main St"
      assert html =~ "Address"
    end

    test "with nil value returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location"
      }

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :display,
          field: definition,
          value: nil
        })

      assert html =~ "<div>"
    end
  end

  describe "render_list/1" do
    test "with Geo.Point value returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location"
      }

      value = %Geo.Point{
        coordinates: {-74.0, 40.0},
        properties: %{"address" => "123 Main St"}
      }

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :list,
          field: definition,
          value: value
        })

      assert html =~ "40.0"
      assert html =~ "74.0"
    end
  end

  describe "render_form/1" do
    test "with map value returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location"
      }

      value = %{
        "coordinates" => [-74.0, 40.0],
        "properties" => %{"address" => "123 Main St"}
      }

      form = Phoenix.Component.to_form(%{"location" => value})

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :form,
          field: form[:location],
          definition: definition
        })

      assert html =~ "grid"
    end

    test "with Geo.Point value returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location"
      }

      value = %Geo.Point{
        coordinates: {-74.0, 40.0},
        properties: %{"address" => "123 Main St"}
      }

      form = Phoenix.Component.to_form(%{"location" => value})

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :form,
          field: form[:location],
          definition: definition
        })

      assert html =~ "grid"
    end

    test "with address_fun option returns rendered HTML" do
      definition = %Field{
        key: :location,
        module: Blank.Fields.Location,
        label: "Location",
        address_fun: fn _query -> {:ok, []} end
      }

      value = %{
        "coordinates" => [-74.0, 40.0],
        "properties" => %{"address" => "123 Main St"}
      }

      form = Phoenix.Component.to_form(%{"location" => value})

      html =
        render_component(&Blank.Fields.Location.render/1, %{
          type: :form,
          field: form[:location],
          definition: definition
        })

      assert html =~ "grid"
    end
  end
end
