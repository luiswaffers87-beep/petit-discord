defmodule MiniDiscord.MixProject do
  use Mix.Project

  def project do
    [app: :mini_discord_client, version: "0.1.0", elixir: "~> 1.14"]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
