defmodule Rounder.Mixfile do
  use Mix.Project

  def project do
    [
      app:     :rounder,
      version: "0.0.1",
      elixir:  "~> 1.2",
      deps:    deps,
      escript: escript,
      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
    ]
  end

  def application do
    [applications: [
        :logger,
        :tzdata,
        :httpoison,
      ]
    ]
  end

  defp deps do
    [
      {:httpoison ,"~> 0.8" },
      {:poison    ,"~> 1.5" },
      {:timex     ,"~> 0.19"},
      {:tzdata    ,"== 0.1.8", override: true}
    ]
  end

  defp escript do
    [main_module: Rounder.CLI]
  end
end
