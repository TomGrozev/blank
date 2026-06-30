defmodule Blank.Fields.DateTimeTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with datetime and UTC time zone returns rendered HTML" do
      definition = %Field{
        key: :published_at,
        module: Blank.Fields.DateTime,
        label: "Published at"
      }

      html =
        render_component(&Blank.Fields.DateTime.render/1, %{
          type: :display,
          field: definition,
          value: ~U[2024-01-15 14:30:00Z],
          time_zone: "Etc/UTC"
        })

      assert html =~ "2024"
    end

    test "with datetime and non-UTC time zone returns rendered HTML" do
      definition = %Field{
        key: :published_at,
        module: Blank.Fields.DateTime,
        label: "Published at"
      }

      html =
        render_component(&Blank.Fields.DateTime.render/1, %{
          type: :display,
          field: definition,
          value: ~U[2024-01-15 14:30:00Z],
          time_zone: "America/New_York"
        })

      assert html =~ "2024"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML" do
      definition = %Field{
        key: :published_at,
        module: Blank.Fields.DateTime,
        label: "Published at"
      }

      html =
        render_component(&Blank.Fields.DateTime.render/1, %{
          type: :form,
          field: build_form_field(:published_at, "2024-01-15T14:30"),
          definition: definition
        })

      assert html =~ "Published at"
    end
  end

  defp build_form_field(field_name, value) do
    form = Phoenix.Component.to_form(%{Atom.to_string(field_name) => value})
    form[field_name]
  end
end
