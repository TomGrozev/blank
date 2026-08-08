defmodule Blank.Types.RoleTest do
  use ExUnit.Case, async: true

  alias Blank.Types.Role

  describe "type/0" do
    test "returns :string" do
      assert Role.type() == :string
    end
  end

  describe "cast/1" do
    test "casts a valid atom role" do
      assert {:ok, :system_admin} = Role.cast(:system_admin)
      assert {:ok, :member} = Role.cast(:member)
    end

    test "casts a configured atom role" do
      assert {:ok, :content_editor} = Role.cast(:content_editor)
    end

    test "returns :error for an atom outside the allowed-set" do
      assert :error = Role.cast(:nonexistent_role)
    end

    test "casts a valid string role" do
      # :system_admin and :member are existing atoms (built-in)
      assert {:ok, :system_admin} = Role.cast("system_admin")
      assert {:ok, :member} = Role.cast("member")
    end

    test "casts a configured string role" do
      assert {:ok, :content_editor} = Role.cast("content_editor")
    end

    test "returns :error for a string that doesn't match an existing atom" do
      assert :error = Role.cast("totally_nonexistent_atom_xyz")
    end

    test "returns :error for a string matching an existing atom but outside allowed-set" do
      # :nil is an existing atom but not an allowed role
      assert :error = Role.cast("nil")
    end

    test "returns :error for non-atom, non-string values" do
      assert :error = Role.cast(123)
      assert :error = Role.cast(nil)
      assert :error = Role.cast(%{})
    end
  end

  describe "dump/1" do
    test "dumps an atom to string" do
      assert {:ok, "system_admin"} = Role.dump(:system_admin)
      assert {:ok, "member"} = Role.dump(:member)
    end

    test "returns :error for non-atoms" do
      assert :error = Role.dump("system_admin")
      assert :error = Role.dump(123)
    end
  end

  describe "load/1" do
    test "loads a string as an atom" do
      assert {:ok, :system_admin} = Role.load("system_admin")
      assert {:ok, :member} = Role.load("member")
    end
  end

  describe "equal?/2" do
    test "returns true for equal atoms" do
      assert Role.equal?(:system_admin, :system_admin)
    end

    test "returns false for different atoms" do
      refute Role.equal?(:system_admin, :member)
    end
  end

  describe "embed_as/1" do
    test "returns :self" do
      assert Role.embed_as(:anything) == :self
    end
  end
end
