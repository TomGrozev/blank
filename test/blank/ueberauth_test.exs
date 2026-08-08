defmodule Blank.UeberauthTest do
  use ExUnit.Case, async: true

  alias Blank.Ueberauth

  describe "provider_display_name/1 with atom" do
    test "converts atom to string and humanizes" do
      # No config for :github, so falls back to Phoenix.Naming.humanize("github")
      assert Ueberauth.provider_display_name(:github) == "Github"
    end

    test "converts atom to string and returns config name when configured" do
      original_auth = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, providers: %{google: %{name: "Google Cloud"}})

        assert Ueberauth.provider_display_name(:google) == "Google Cloud"
      after
        Application.put_env(:blank, :auth, original_auth)
      end
    end
  end

  describe "provider_display_name/1 with string" do
    test "returns config name when configured" do
      original_auth = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, providers: %{github: %{name: "GitHub Enterprise"}})

        assert Ueberauth.provider_display_name("github") == "GitHub Enterprise"
      after
        Application.put_env(:blank, :auth, original_auth)
      end
    end

    test "falls back to Phoenix.Naming.humanize when no config" do
      assert Ueberauth.provider_display_name("github") == "Github"
    end

    test "falls back to Phoenix.Naming.humanize when providers not configured" do
      original_auth = Application.get_env(:blank, :auth, [])

      try do
        Application.put_env(:blank, :auth, [])

        assert Ueberauth.provider_display_name("google") == "Google"
      after
        Application.put_env(:blank, :auth, original_auth)
      end
    end
  end

  describe "provider_display_name/1 with unknown type" do
    test "returns Nil for nil (nil is an atom, goes through atom clause)" do
      # nil is an atom, so it matches the is_atom clause:
      # Atom.to_string(nil) => "nil", then humanize("nil") => "Nil"
      assert Ueberauth.provider_display_name(nil) == "Nil"
    end

    test "returns Unknown for integer" do
      assert Ueberauth.provider_display_name(42) == "Unknown"
    end

    test "returns Unknown for list" do
      assert Ueberauth.provider_display_name([:google]) == "Unknown"
    end
  end

  describe "provider_display_name/1 atom-to-string delegation" do
    test "atom delegates to string version" do
      # :github -> "github" -> humanize -> "Github"
      result_atom = Ueberauth.provider_display_name(:github)
      result_string = Ueberauth.provider_display_name("github")
      assert result_atom == result_string
    end
  end

  describe "provider_display_name/1 security" do
    test "does not create new atoms for unknown provider strings" do
      # Capture the atom table before the call
      before_atoms = :erlang.system_info(:atom_count)

      # Use a string that is definitely NOT an existing atom
      unique = "totally_unknown_provider_#{System.unique_integer([:positive])}"
      result = Ueberauth.provider_display_name(unique)

      # Should still return a humanized string (not crash)
      assert is_binary(result)
      assert result != ""

      # The atom count should NOT have increased
      after_atoms = :erlang.system_info(:atom_count)

      assert after_atoms == before_atoms,
             "provider_display_name/1 created a new atom for unknown input"
    end

    test "returns humanized name for unknown provider string" do
      unique = "custom_provider_xyz"
      result = Ueberauth.provider_display_name(unique)
      # Should fall back to Phoenix.Naming.humanize
      assert result == Phoenix.Naming.humanize(unique)
    end
  end
end
