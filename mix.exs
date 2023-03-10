defmodule Aja.MixProject do
  use Mix.Project

  @version "0.6.2"

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
        "test.unit": :test,
        "test.prop": :test
      ],

      # Hex
      description:
        "Extension of the Elixir standard library focused on data stuctures, data manipulation and performance",
      package: package(),

      # Docs
      name: "Aja",
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [flags: [:missing_return]]
    ]
  end

  # fixing https://elixirforum.com/t/confusing-behavior-of-optional-deps-in-mix-exs/17719
  def application do
    case Mix.env() do
      :dialyzer ->
        [
          extra_applications: [:jason]
        ]

      :test ->
        [
          extra_applications: [:stream_data]
        ]

      _ ->
        []
    end
  end

  defp deps do
    [
      # OPTIONAL DEPENDENCIES
      {:jason, "~> 1.2", optional: true},

      # CI
      {:dialyxir, "~> 1.0", only: :dialyzer, runtime: false},
      {:stream_data, "~> 0.5", only: [:test, :dev], runtime: false},

      # DOCS
      {:ex_doc, "~> 0.28", only: :docs, runtime: false},

      # BENCHMARKING
      {:benchee, "~> 1.0", only: :bench, runtime: false}
    ]
  end

  defp aliases do
    [
      "test.prop": ["test --only property:true"],
      "test.unit": ["test --exclude property:true"]
    ]
  end

  defp package do
    [
      maintainers: ["sabiwara"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sabiwara/aja"},
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md images/logo_small.png)
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "images/logo_small.png",
      source_ref: "v#{@version}",
      source_url: "https://github.com/sabiwara/aja",
      homepage_url: "https://github.com/sabiwara/aja",
      extra_section: "Pages",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
