# ![Logo](https://github.com/am-kantox/exvalibur/blob/master/stuff/logo-48x48.png?raw=true) Exvalibur

[![CircleCI](https://circleci.com/gh/am-kantox/exvalibur.svg?style=svg)](https://circleci.com/gh/am-kantox/exvalibur)     **generator for blazingly fast validators of maps based on sets of predefined rules**

## Installation

Simply add `exvalibur` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exvalibur, "~> 0.1"}
  ]
end
```

## Usage

```elixir
rules = [
  %{matches: %{currency_pair: "EURUSD"},
    conditions: %{rate: %{min: 1.0, max: 2.0}}}]
Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
#⇒ {:ok, %{currency_pair: "EURUSD", rate: 1.5}}
Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
#⇒ :error
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 0.5})
#⇒ :error

rules = [
  %{matches: %{currency_pair: "EURGBP"},
    conditions: %{rate: %{min: 1.0, max: 2.0}}}]
Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
#⇒ {:ok, %{currency_pair: "EURGBP", rate: 1.5}}
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
#⇒ {:ok, %{currency_pair: "EURUSD", rate: 1.5}}
```

## Documentation

Documentation is available at [https://hexdocs.pm/exvalibur](https://hexdocs.pm/exvalibur).

