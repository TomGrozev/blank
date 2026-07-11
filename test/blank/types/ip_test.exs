defmodule Blank.Types.IPTest do
  use ExUnit.Case, async: true

  alias Blank.Types.IP

  test "type/0 is :string" do
    assert IP.type() == :string
  end

  test "cast/1 from binary" do
    assert {:ok, {192, 168, 1, 1}} = IP.cast("192.168.1.1")
  end

  test "cast/1 from tuple" do
    assert {:ok, {10, 0, 0, 1}} = IP.cast({10, 0, 0, 1})
  end

  test "cast/1 from invalid" do
    assert {:error, _} = IP.cast("not an ip")
  end

  test "load/1 from binary" do
    assert {:ok, {10, 0, 0, 1}} = IP.load("10.0.0.1")
  end

  test "load/1 from ipv6 binary" do
    assert {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} = IP.load("::1")
  end

  test "load/1 from invalid" do
    assert {:error, _} = IP.load("nope")
  end

  test "dump/1 from tuple" do
    assert {:ok, "192.168.1.1"} = IP.dump({192, 168, 1, 1})
  end

  test "dump/1 from non-tuple" do
    assert :error = IP.dump("binary")
  end

  test "equal?/2 with same string values" do
    assert IP.equal?("10.0.0.1", "10.0.0.1") == true
  end

  test "equal?/2 with different values" do
    assert IP.equal?("10.0.0.1", "10.0.0.2") == false
  end

  test "embed_as/1 is :self" do
    assert IP.embed_as(:anything) == :self
  end
end
