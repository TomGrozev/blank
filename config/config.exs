import Config

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end

if Mix.env() != :prod do
  config :git_hooks,
    auto_install: true,
    verbose: true,
    hooks: [
      pre_commit: [
        tasks: [
          {:cmd, "mix precommit"}
        ]
      ],
      pre_push: [
        verbose: false,
        tasks: [
          {:cmd, "mix precommit"}
        ]
      ]
    ]
end
