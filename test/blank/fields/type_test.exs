defmodule Blank.Fields.TypeTest do
  use ExUnit.Case, async: true

  alias Blank.Fields.Type

  describe "module_for_type/1" do
    test "module_for_type/1 maps :boolean to Boolean" do
      assert Type.module_for_type(:boolean) == Blank.Fields.Boolean
    end

    test "module_for_type/1 maps :utc_datetime to DateTime" do
      assert Type.module_for_type(:utc_datetime) == Blank.Fields.DateTime
    end

    test "module_for_type/1 maps unknown to Text" do
      assert Type.module_for_type(:string) == Blank.Fields.Text
      assert Type.module_for_type(:integer) == Blank.Fields.Text
      assert Type.module_for_type(:foo) == Blank.Fields.Text
    end
  end
end
