defmodule Blank.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/TomGrozev/blank"

  def project do
    [
      app: :blank,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls, threshold: 80],
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

  # The repo-owned gate: the pre-commit hook, CI and agents all run `mix precommit`.
  # `sobelow` keeps CI's form: the three low-confidence findings are triaged (commit 459f9f7).
  # `xref --fail-above 3` permits the three known cycles (issue #34) and fails on a fourth.
  defp aliases do
    [
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "doctor --summary",
        "sobelow",
        "xref graph --format cycles --fail-above 3",
        "test --cover"
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
      {:phoenix_ecto, "~> 4.5"},
      {:arangox_ecto, "~> 2.0", optional: true},
      {:flop, "~> 0.29"},
      {:flop_phoenix, "~> 0.27"},
      {:gettext, "~> 1.0"},
      {:nimble_options, "~> 1.1"},
      {:eqrcode, "~> 0.2"},
      {:csv, "~> 3.2"},
      {:geo, "~> 3.6", optional: true},
      {:tz, "~> 0.28"},
      {:ueberauth, "~> 0.10"},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      # 1.7.19 is the first release whose tokenizer handles the Elixir 1.20 AST.
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:git_hooks, "~> 0.8", only: [:dev], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ecto_sql, "~> 3.10", only: :test, runtime: false},
      # Started explicitly in test/test_helper.exs. Without runtime: false the
      # test adapter lands in blank.app's applications list, which then claims a
      # dependency the library does not have.
      {:ecto_sqlite3, "~> 0.15", only: :test, runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Tom Grozev"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md LICENSE CHANGELOG.md lib priv guides)
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
          Blank.Audit.AuditLog,
          Blank.Audit.Context
        ],
        "Ecto Types": [
          Blank.Types.IP
        ],
        Fields: [
          Blank.Field,
          Blank.Fields.BelongsTo,
          Blank.Fields.Boolean,
          Blank.Fields.Currency,
          Blank.Fields.DateTime,
          Blank.Fields.HasMany,
          Blank.Fields.List,
          Blank.Fields.Location,
          Blank.Fields.Password,
          Blank.Fields.QRCode,
          Blank.Fields.Text
        ],
        Authorization: ~r/Blank\.Authorization/,
        Accounts: ~r/Blank\.Accounts/,
        Exporters: ~r/Blank\.Exporters/,
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
      # Introduction
      "guides/introduction/Getting Started.md",
      "guides/introduction/Authentication.md",
      "guides/introduction/Authorization.md",
      "guides/introduction/Role Mappers.md",
      "guides/introduction/Architecture.md",
      "guides/introduction/Glossary.md",
      "guides/introduction/Troubleshooting.md",
      "guides/introduction/Upgrading.md",
      # Cheatsheets
      "guides/cheatsheets/Configuration.md",
      "guides/cheatsheets/Mix Tasks.md",
      "guides/cheatsheets/Schema Options.md",
      "guides/cheatsheets/AdminPage Options.md",
      "guides/cheatsheets/Field Options.md",
      # How-Tos
      "guides/howtos/Custom Field.md",
      "guides/howtos/Custom Exporter.md",
      "guides/howtos/Custom Stats.md",
      "guides/howtos/Audit Logging.md",
      "guides/howtos/Routing.md",
      "guides/howtos/Import.md",
      # Other
      "CHANGELOG.md"
    ]
  end

  # defp group_for_function(group), do: {String.to_atom(group), &(&1[:group] == group)}

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Cheatsheets: ~r/guides\/cheatsheets\/.?/,
      "How-To's": ~r/guides\/howtos\/.?/
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
