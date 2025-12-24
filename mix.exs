defmodule Blank.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/TomGrozev/blank"

  def project do
    [
      app: :blank,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      # Hex
      description: "Blank is a drop-in admin panel for your elixir projects.",
      package: package(),
      # Docs
      name: "Blank",
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test,
        "coveralls.html": :test
      ]
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
      {:phoenix_live_view, "~> 1.1.0"},
      {:arangox_ecto, "~> 2.0", optional: true},
      {:flop, "~> 0.26"},
      {:flop_phoenix, "~> 0.25"},
      {:gettext, "~> 1.0"},
      {:nimble_options, "~> 1.1"},
      {:eqrcode, "~> 0.2"},
      {:csv, "~> 3.2"},
      {:geo, "~> 3.6", optional: true},
      {:tz, "~> 0.28"},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:git_hooks, "~> 0.8", only: [:dev], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Tom Grozev"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md lib)
    ]
  end

  defp docs do
    [
      main: "Blank",
      source_ref: "v#{@version}",
      logo: "priv/static/images/blank-black.png",
      extra_section: "GUIDES",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: extras(),
      before_closing_head_tag: &before_closing_head_tag/1,
      groups_for_extras: groups_for_extras(),
      # groups_for_docs: [
      #   group_for_function("Fields")
      # ],
      groups_for_modules: [
        "Audit Logging": [
          Blank.Audit,
          Blank.Audit.AuditLog
        ],
        "Ecto Types": [
          Blank.Types.IP
        ],
        Fields: [
          Blank.Field,
          Blank.Fields.BelongsTo,
          Blank.Fields.Boolean,
          Blank.Fields.DateTime,
          Blank.Fields.HasMany,
          Blank.Fields.List,
          Blank.Fields.Location,
          Blank.Fields.Password,
          Blank.Fields.QRCode,
          Blank.Fields.Text
        ],
        Plugs: [
          Blank.Plugs.AuditContext
        ],
        Statistics: [
          Blank.Stats,
          Blank.Stats.Value
        ]
      ],
      canonical: "http://hex.pm/blank"
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script>
      function mermaidLoaded() {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      }
    </script>
    <script async src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js" onload="mermaidLoaded();"></script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp extras do
    [
      "guides/introduction/Getting Started.md",
      "CHANGELOG.md"
    ]
  end

  # defp group_for_function(group), do: {String.to_atom(group), &(&1[:group] == group)}

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Cheatsheets: ~r/guides\/cheetsheets\/.?/,
      "How-To's": ~r/guides\/howtos\/.?/
    ]
  end
end
