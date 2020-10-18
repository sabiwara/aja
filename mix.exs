defmodule Aja.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :aja,
      version: @version,
      elixir: "~> 1.10",
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
      preferred_cli_env: [
        inch: :docs,
        docs: :docs,
        "hex.publish": :docs,
        dialyzer: :dialyzer,
        cover: :test,
        propertest: :test
      ],

      # Hex
      description:
        "Extension of the Elixir standard library focused on data stuctures and data manipulation",
      package: package(),

      # Docs
      name: "Aja",
      docs: docs()
    ]
  end

  # fixing https://elixirforum.com/t/confusing-behavior-of-optional-deps-in-mix-exs/17719
  def application do
    case Mix.env() do
      :dialyzer ->
        [
          extra_applications: [:jason],
          mod: {A.Application, []}
        ]

      _ ->
        []
    end
  end

  defp deps do
    [
      # OPTIONAL DEPENDENCIES
      {:jason, "~> 1.0", optional: true},

      # CI
      {:dialyxir, "~> 1.0", only: :dialyzer, runtime: false},
      {:stream_data, "~> 0.5", only: :test, runtime: false},

      # DOCS
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:inch_ex, "~> 2.0", only: :docs, runtime: false},

      # BENCHMARKING
      {:benchee, "~> 1.0", only: :bench, runtime: false}
    ]
  end

  defp aliases do
    [
      propertest: ["test --include property:true"]
    ]
  end

  defp package do
    [
      maintainers: ["sabiwara"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sabiwara/aja"},
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/sabiwara/aja",
      homepage_url: "https://github.com/sabiwara/aja",
      extra_section: "Pages",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"]
    ]
  end
end
