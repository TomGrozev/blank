defmodule Blank.StatsTest do
  use ExUnit.Case, async: true

  describe "named_value/2" do
    test "formats value with the module's plural_name" do
      assert Blank.Stats.named_value(Blank.Pages.AdminsLive, 2) == "2 admins"
    end

    test "formats zero value" do
      assert Blank.Stats.named_value(Blank.Pages.AdminsLive, 0) == "0 admins"
    end

    test "formats with TestAppWeb.Admin.PostLive plural_name" do
      # PostLive has plural_name: "posts"
      result = Blank.Stats.named_value(TestAppWeb.Admin.PostLive, 5)
      assert result == "5 posts"
    end
  end

  describe "named_value/3" do
    test "formats value with the module's singular name" do
      assert Blank.Stats.named_value(Blank.Pages.AdminsLive, :any, 2) == "2 admin"
    end

    test "formats zero value with singular name" do
      assert Blank.Stats.named_value(Blank.Pages.AdminsLive, :count, 0) == "0 admin"
    end

    test "formats with TestAppWeb.Admin.PostLive name" do
      # PostLive has name: "post"
      result = Blank.Stats.named_value(TestAppWeb.Admin.PostLive, :total, 3)
      assert result =~ "3"
      assert result =~ "post"
    end
  end
end
