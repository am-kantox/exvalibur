# ![Logo](/stuff/logo-48x48.png?raw=true) Exvalibur

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

## Sigils To Pattern Match Data

Starting with `0.4.0` we support `~v` and `~V` sigils to use validator with
pattern matching.

```elixir
  import Exvalibur.Sigils

  starting_with = "bar"
  rules = [%{matches: %{foo: ~v[<<"#{starting_with}", _::binary>>]}}]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
  assert TestValidator.valid?(%{foo: "zzz"}) == :error
  assert TestValidator.valid?(%{foo: 42}) == :error
```

Any match expression allowed in function head matching clause is allowed here.

```elixir
  import Exvalibur.Sigils

  rules = [%{matches: %{foo: ~V[%{} = _]}}]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{foo: %{bar: "baz"}}) == {:ok, %{foo: %{bar: "baz"}}}
  assert TestValidator.valid?(%{foo: 42}) == :error
```

## Documentation

Documentation is available at [https://hexdocs.pm/exvalibur](https://hexdocs.pm/exvalibur).

