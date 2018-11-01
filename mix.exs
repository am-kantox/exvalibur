defmodule Exvalibur.MixProject do
  use Mix.Project

  def project do
    [
      app: :exvalibur,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:nimble_csv, git: "https://github.com/plataformatec/nimble_csv.git", branch: "master"},
      {:gen_stage, "~> 0.14"},
      {:flow, "~> 0.14"},
      {:credo, "~> 1.0.0-rc1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:benchee, "~> 0.11", only: :dev},
      {:benchee_csv, "~> 0.7", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end
