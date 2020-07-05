defmodule DiceStats.MixProject do
  use Mix.Project

  def project do
    [
      app: :dice_stats,
      version: "0.1.0",
      elixir: "~> 1.10",
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
      {:ex_dice_roller, "~> 1.0.0-rc.2"},
      {:elixlsx, "~> 0.4.2"}
    ]
  end
end
