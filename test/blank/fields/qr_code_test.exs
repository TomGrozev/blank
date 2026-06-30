defmodule Blank.Fields.QRCodeTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Blank.Field

  describe "update/2" do
    test "sets qr_code and download_path for value with path" do
      definition = %Field{
        key: :barcode,
        module: Blank.Fields.QRCode,
        label: "Barcode",
        path: "/items"
      }

      assigns = %{
        value: "my-code",
        definition: definition,
        path_prefix: "/"
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = Blank.Fields.QRCode.update(assigns, socket)

      assert updated_socket.assigns.qr_code =~ "<svg"
      assert updated_socket.assigns.download_path =~ "/qrcode"
      assert updated_socket.assigns.download_path =~ "code=my-code"
    end

    test "update with fallback clause just assigns" do
      definition = %Field{
        key: :barcode,
        module: Blank.Fields.QRCode,
        label: "Barcode"
      }

      assigns = %{
        value: "test-code",
        definition: definition
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:ok, updated_socket} = Blank.Fields.QRCode.update(assigns, socket)

      assert updated_socket.assigns.qr_code =~ "<svg"
      assert updated_socket.assigns.download_path =~ "/qrcode"
    end
  end

  describe "render_list/1" do
    test "returns rendered HTML with raw value" do
      definition = %Field{
        key: :barcode,
        module: Blank.Fields.QRCode,
        label: "Barcode"
      }

      html =
        render_component(&Blank.Fields.QRCode.render/1, %{
          type: :list,
          field: definition,
          value: "my-code"
        })

      assert html =~ "my-code"
    end
  end

  describe "render_display/1" do
    test "returns rendered HTML with QR code and value" do
      definition = %Field{
        key: :barcode,
        module: Blank.Fields.QRCode,
        label: "Barcode"
      }

      html =
        render_component(&Blank.Fields.QRCode.render/1, %{
          type: :display,
          field: definition,
          value: "my-code",
          qr_code: "<svg>test</svg>",
          download_path: "/qrcode?code=my-code&path=/"
        })

      assert html =~ "my-code"
      assert html =~ "<svg"
    end
  end

  describe "render_form/1" do
    test "returns rendered HTML" do
      definition = %Field{
        key: :barcode,
        module: Blank.Fields.QRCode,
        label: "Barcode"
      }

      form = Phoenix.Component.to_form(%{"barcode" => "my-code"})

      html =
        render_component(&Blank.Fields.QRCode.render/1, %{
          type: :form,
          field: form[:barcode],
          definition: definition
        })

      assert html =~ "Barcode"
    end
  end
end
