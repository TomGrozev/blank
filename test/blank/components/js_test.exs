defmodule Blank.Components.JSTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.JS

  describe "show/2" do
    test "returns a %JS{} struct" do
      assert %JS{} = Blank.Components.JS.show("#foo")
    end

    test "chains onto an existing JS struct" do
      base = %JS{}
      assert %JS{} = Blank.Components.JS.show(base, "#bar")
    end

    test "contains show operations" do
      js = Blank.Components.JS.show("#foo")
      assert js.ops != []
    end
  end

  describe "hide/2" do
    test "returns a %JS{} struct" do
      assert %JS{} = Blank.Components.JS.hide("#foo")
    end

    test "chains onto an existing JS struct" do
      base = %JS{}
      assert %JS{} = Blank.Components.JS.hide(base, "#bar")
    end

    test "contains hide operations" do
      js = Blank.Components.JS.hide("#foo")
      assert js.ops != []
    end
  end

  describe "show_modal/2" do
    test "returns a %JS{} struct" do
      assert %JS{} = Blank.Components.JS.show_modal("my-modal")
    end

    test "contains multiple operations" do
      js = Blank.Components.JS.show_modal("my-modal")
      # show_modal chains multiple ops: show, show bg, show container, add_class, focus_first
      assert length(js.ops) >= 4
    end
  end

  describe "hide_modal/2" do
    test "returns a %JS{} struct" do
      assert %JS{} = Blank.Components.JS.hide_modal("my-modal")
    end

    test "contains multiple operations" do
      js = Blank.Components.JS.hide_modal("my-modal")
      # hide_modal chains: hide bg, hide container, hide modal, remove_class, pop_focus
      assert length(js.ops) >= 4
    end
  end
end
