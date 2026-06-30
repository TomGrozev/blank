defmodule Blank.Fields.CurrencyTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "with a numeric value returns formatted currency" do
      definition = %Field{key: :price, module: Blank.Fields.Currency, label: "Price"}

      html =
        render_component(&Blank.Fields.Currency.render/1, %{
          type: :display,
          field: definition,
          value: 19.99
        })

      assert html =~ "$19.99"
    end

    test "with nil value returns $0.00" do
      definition = %Field{key: :price, module: Blank.Fields.Currency, label: "Price"}

      html =
        render_component(&Blank.Fields.Currency.render/1, %{
          type: :display,
          field: definition,
          value: nil
        })

      assert html =~ "$0.00"
    end

    test "with zero float value returns $0.00" do
      definition = %Field{key: :price, module: Blank.Fields.Currency, label: "Price"}

      html =
        render_component(&Blank.Fields.Currency.render/1, %{
          type: :display,
          field: definition,
          value: 0.0
        })

      assert html =~ "$0.00"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML with number input" do
      definition = %Field{key: :price, module: Blank.Fields.Currency, label: "Price"}
      form = Phoenix.Component.to_form(%{"price" => "19.99"})

      html =
        render_component(&Blank.Fields.Currency.render/1, %{
          type: :form,
          field: form[:price],
          definition: definition
        })

      assert html =~ "Price"
      assert html =~ "number"
    end
  end
end
