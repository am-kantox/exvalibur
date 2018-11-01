defmodule Exvalibur.MixProject do
  use Mix.Project

  @app :exvalibur
  @app_name "Exvalibur"
  @version "0.2.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      package: package(),
      xref: [exclude: []],
      description: description(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_csv, "~> 0.4"},
      {:gen_stage, "~> 0.14"},
      {:flow, "~> 0.14"},
      {:credo, "~> 1.0.0-rc1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:benchee, "~> 0.11", only: :dev},
      {:benchee_csv, "~> 0.7", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end


  defp description do
    """
    The generator of blazingly fast validator for map input.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|config lib mix.exs README.md|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs() do
    [
      main: @app_name,
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48x48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: [
        # "stuff/#{@app_name}.md",
        # "stuff/backends.md"
      ],
      groups_for_modules: [
        # Exvalibur

        "Default Guards": [
          Exvalibur.Guards.Default
        ]
      ]
    ]
  end
end
