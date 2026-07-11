defmodule Blank.Utils.QRCodeTest do
  use ExUnit.Case, async: false

  alias Blank.Utils.QRCode

  describe "svg/2" do
    test "returns a non-empty SVG string with default path" do
      result = QRCode.svg("test-code")
      assert is_binary(result)
      assert byte_size(result) > 0
      assert result =~ "<svg"
    end

    test "returns a non-empty SVG string with custom path" do
      result = QRCode.svg("test-code", "/items")
      assert is_binary(result)
      assert byte_size(result) > 0
      assert result =~ "<svg"
    end
  end

  describe "png/2" do
    test "returns a non-empty PNG binary with default path" do
      result = QRCode.png("test-code")
      assert is_binary(result)
      assert byte_size(result) > 0
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = result
    end

    test "returns a non-empty PNG binary with custom path" do
      result = QRCode.png("test-code", "/items")
      assert is_binary(result)
      assert byte_size(result) > 0
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = result
    end
  end
end
