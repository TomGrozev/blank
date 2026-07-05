defmodule Blank.StatsTest do
  use ExUnit.Case, async: true

  describe "named_value/2" do
    test "formats value with the module's plural_name" do
      assert Blank.Stats.named_value(Blank.Pages.UsersLive, 2) == "2 users"
    end

    test "formats zero value" do
      assert Blank.Stats.named_value(Blank.Pages.UsersLive, 0) == "0 users"
    end

    test "formats with TestAppWeb.Admin.PostLive plural_name" do
      # PostLive has plural_name: "posts"
      result = Blank.Stats.named_value(TestAppWeb.Admin.PostLive, 5)
      assert result == "5 posts"
    end
  end

  describe "named_value/3" do
    test "formats value with the module's singular name" do
      assert Blank.Stats.named_value(Blank.Pages.UsersLive, :any, 2) == "2 user"
    end

    test "formats zero value with singular name" do
      assert Blank.Stats.named_value(Blank.Pages.UsersLive, :count, 0) == "0 user"
    end

    test "formats with TestAppWeb.Admin.PostLive name" do
      # PostLive has name: "post"
      result = Blank.Stats.named_value(TestAppWeb.Admin.PostLive, :total, 3)
      assert result =~ "3"
      assert result =~ "post"
    end
  end
end
