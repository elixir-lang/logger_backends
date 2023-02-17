defmodule LoggerBackends.MixProject do
  use Mix.Project

  @version "1.0.0-rc.0"
  @url "https://github.com/elixir-lang/logger_backends"

  def project do
    [
      app: :logger_backends,
      version: @version,
      elixir: "~> 1.15-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      preferred_cli_env: [docs: :docs, "hex.publish": :docs],

      # Hex
      description: "Logger backends functionality for Elixir v1.15+",
      package: [
        maintainers: ["Elixir Team"],
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => @url}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LoggerBackends.Application, []}
    ]
  end

  defp docs do
    [
      main: "LoggerBackends",
      source_ref: "v#{@version}",
      source_url: @url
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.28", only: :docs}
    ]
  end
end
