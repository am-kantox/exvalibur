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

Starting with `v0.4.0` we support `~q` and `~Q` sigils to use validator with
pattern matching.

```elixir
  import Exvalibur.Sigils

  starting_with = "bar"
  rules = [%{matches: %{foo: ~q[<<"#{starting_with}", _::binary>>]}}]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
  assert TestValidator.valid?(%{foo: "zzz"}) == :error
  assert TestValidator.valid?(%{foo: 42}) == :error
```

## Binary Conditions

Starting with `v0.5.0` we support binary conditions for the declared guards.

```elixir
  import Exvalibur.Sigils

  rules = [%{conditions: "num >= 0 and num <= 100"}]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{num: "bar"}) == :error
  assert TestValidator.valid?(%{num: 200}) == :error
  assert TestValidator.valid?(%{num: 42}) == {:ok, %{num: 42}}
```

Any match expression allowed in function head matching clause is allowed here.

```elixir
  import Exvalibur.Sigils

  rules = [%{matches: %{foo: ~Q[%{} = _]}}]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{foo: %{bar: "baz"}}) == {:ok, %{foo: %{bar: "baz"}}}
  assert TestValidator.valid?(%{foo: 42}) == :error
```

## Custom Guards

Starting with `v0.6.0` we support arbitrary custom guards in rules. The variables
used in these guards should be explicitly declared under the `matches` key in rules,
in the form `foo: ~Q[foo]`.

```elixir
  import Exvalibur.Sigils

  rules = [%{
    matches: %{num: ~Q[num]},
    guards: ["num >= 0 and num <= 100"]
  }]

  Exvalibur.validator!(rules, module_name: TestValidator)

  assert TestValidator.valid?(%{num: "bar"}) == :error
  assert TestValidator.valid?(%{num: 200}) == :error
  assert TestValidator.valid?(%{num: 42}) == {:ok, %{num: 42}}
```

## Module-based validators

```elixir
defmodule Validator do
  use Exvalibur, rules: [
    %{
      matches: %{currency_pair: <<"EUR", _ :: binary>>},
      conditions: %{foo: %{min: 0, max: 100}},
      guards: %{num: num > 0 and num < 100}}]
end
Validator.valid?(%{currency_pair: "EURUSD", foo: 50, num: 50})
#⇒ {:ok, %{currency_pair: "EURUSD", foo: 50, num: 50}}

Validator.valid?(%{currency_pair: "USDEUR", foo: 50, num: 50})
#⇒ :error
Validator.valid?(%{currency_pair: "EURUSD", foo: -50, num: 50})
#⇒ :error
Validator.valid?(%{currency_pair: "EURUSD", foo: 50, num: -50})
#⇒ :error
```

## Changelog

#### `0.9.0`

- `valid?/1` is deprecated in favor of `validate/1`; starting with `v1.0` `valid?/1` will return `boolean` value

#### `0.8.0`

- module-based validators

## [Documentation](https://hexdocs.pm/exvalibur).

