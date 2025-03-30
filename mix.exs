defmodule Blank.MixProject do
  use Mix.Project

  def project do
    [
      app: :blank,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Blank.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:arangox_ecto, "~> 2.0", optional: true},
      {:flop, "~> 0.26"},
      {:flop_phoenix, "~> 0.24"},
      {:gettext, "~> 0.26"},
      {:nimble_options, "~> 1.1.0"},
      {:eqrcode, "~> 0.2.0"},
      {:csv, "~> 3.2"},
      {:geo, "~> 3.6", optional: true}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
