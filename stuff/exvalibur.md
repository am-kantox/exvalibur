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
  %{matches: %{currency_pair: "EURUSD", valid: ~Q[valid]},
    conditions: %{rate: %{min: 1.0, max: 3.0}},
    guards: "is_boolean(valid)"}]
Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5, valid: true})
#⇒ {:ok, %{currency_pair: "EURUSD", rate: 1.5, valid: true}}
Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
#⇒ :error
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 0.5})
#⇒ :error

rules = [
  %{matches: %{currency_pair: ~Q[<<"EUR", _::binary>>]},
    conditions: %{rate: %{min: 1.0, max: 2.0}}}]
Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
#⇒ {:ok, %{currency_pair: "EURGBP", rate: 1.5}}
Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
#⇒ {:ok, %{currency_pair: "EURUSD", rate: 1.5}}
```

## Sigils

Sigils `~q` and `~Q` can be used to specify a quoted expression to be used in
pattern matching in `matches`.

The condition `%{matches: %{currency_pair: ~Q[<<"EUR", _::binary>>]}` from
the latter example will match any binary value for `currency_pair`, starting with
`"EUR"`.

This sigils also are to be used to enable variables in custom guards. In the
former example `valid: ~Q[valid]` clause makes it possible to use `valid`
variable in custom guard.

## Documentation

Documentation is available at [https://hexdocs.pm/exvalibur](https://hexdocs.pm/exvalibur).

