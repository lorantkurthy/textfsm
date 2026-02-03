defmodule TextFSM.MixProject do
  use Mix.Project

  def project do
    [
      app: :textfsm,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "TextFSM",
      source_url: "https://github.com/amitbashan/textfsm"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"}
    ]
  end

  defp description() do
    """
    TextFSM is a template-based state machine designed to parse semi-structured text (such as CLI output) into structured data.

    This is an Elixir implementation of the original TextFSM written in Python.
    """
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/amitbashan/textfsm"}
    ]
  end
end
