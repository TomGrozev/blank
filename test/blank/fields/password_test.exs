defmodule Blank.Fields.PasswordTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "render_display/1" do
    test "returns rendered HTML showing masked value" do
      definition = %Field{key: :password, module: Blank.Fields.Password, label: "Password"}

      html =
        render_component(&Blank.Fields.Password.render/1, %{
          type: :display,
          field: definition,
          value: "secret123"
        })

      assert html =~ "************"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML with password input" do
      definition = %Field{key: :password, module: Blank.Fields.Password, label: "Password"}
      form = Phoenix.Component.to_form(%{"password" => ""})

      html =
        render_component(&Blank.Fields.Password.render/1, %{
          type: :form,
          field: form[:password],
          definition: definition
        })

      assert html =~ "Password"
      assert html =~ "password"
    end
  end
end
