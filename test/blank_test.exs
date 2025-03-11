defmodule BlankTest do
  use ExUnit.Case
  doctest Blank

  test "greets the world" do
    assert Blank.hello() == :world
  end
end
