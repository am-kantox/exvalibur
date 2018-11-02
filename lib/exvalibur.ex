defmodule Exvalibur do
  @moduledoc """
  `Exvalibur` is the generator for blazingly fast validators of maps based on sets of predefined rules.

  Generally speaking, one provides a list of rules in a format of a map:

      rules = [
        %{matches: %{currency_pair: "EURUSD"},
          conditions: %{rate: %{min: 1.0, max: 2.0}}},
        %{matches: %{currency_pair: "USDEUR"},
          conditions: %{rate: %{min: 1.2, max: 1.3}}},
      ]

  and calls `Exvalibur.validator!/2`. The latter will produce a validator module
  with as many clauses of `valid?/1` function as we have rules above (plus one
  handling-all clause.) Once generated, the `valid?/1` function of the module
  generated might be called directly on the input data, providing blazingly fast
  validation based completely on pattern matching and guards.
  """

  @doc """
  Produces the validator module given the set of rules.

  ## Options

  - `module_name :: binary()` the name of the module to produce; when omitted, it will be looked up in current application options
  - `merge :: boolean()` when true, the existing rules are taken from the module (if exists) and being merged against current rules
  - `flow :: boolean()` when true, the underlying module generator uses [`Flow`](https://hexdocs.pm/flow) to process an input

  ## Example

      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURUSD"},
      ...>     conditions: %{rate: %{min: 1.0, max: 2.0}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
      ...> Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
      {:ok, %{currency_pair: "EURUSD", rate: 1.5}}
      iex> Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
      :error
      iex> Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 0.5})
      :error
      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURGBP"},
      ...>     conditions: %{rate: %{min: 1.0, max: 2.0}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
      ...> Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
      {:ok, %{currency_pair: "EURGBP", rate: 1.5}}
      iex> Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
      {:ok, %{currency_pair: "EURUSD", rate: 1.5}}

  ## Unknown conditions

      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURGBP"},
      ...>     conditions: %{rate: %{perfect: true}}}]
      ...> try do
      ...>   Exvalibur.validator!(rules, module_name: Exvalibur.Validator2)
      ...> rescue
      ...>   e in [Exvalibur.Error] ->
      ...>   e.reason
      ...> end
      %{unknown_guard: :perfect}

  When an unknown guard is passed to the rules conditions, compile-time error is produced

  ## Return value

  Generated `valid?/1` function returns either `:error` or `{:ok, map()}`.
  In a case of successful validation, the map contained values _that were indeed validated_.
  Note that in the following example the value for `any` key is not returned.

      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURGBP"},
      ...>     conditions: %{
      ...>       rate: %{min: 1.0, max: 2.0},
      ...>       source: %{one_of: ["FOO", "BAR"]}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator3, merge: false)
      ...> Exvalibur.Validator3.valid?(%{currency_pair: "EURGBP", any: 42, rate: 1.5, source: "FOO"})
      {:ok, %{currency_pair: "EURGBP", rate: 1.5, source: "FOO"}}
      iex> Exvalibur.Validator3.valid?(%{currency_pair: "EURUSD", any: 42, rate: 1.5, source: "BAH"})
      :error
  """
  @spec validator!(rules :: list(), opts :: list()) :: {:module, module(), binary(), term()}
  def validator!(rules, opts \\ []) when is_list(rules) and is_list(opts) do
    name = get_or_create_module_name(opts, :module_name, "Instance")
    merge = Keyword.get(opts, :merge, true)
    processor = if opts[:flow], do: :flow, else: :enum

    current_rules =
      if Code.ensure_compiled?(name) do
        cr = if merge, do: apply(name, :rules, []), else: %{}
        :code.purge(name)
        :code.delete(name)
        cr
      else
        # no previous rules
        %{}
      end

    Module.create(name, ast(rules, current_rules, processor), Macro.Env.location(__ENV__))
  end

  @doc false
  @spec get_or_create_module_name(
          opts :: Keyword.t(),
          key :: atom(),
          fallback :: binary()
        ) :: atom()
  def get_or_create_module_name(opts, key, fallback)
      when is_list(opts) and is_atom(key) and is_binary(fallback) do
    with nil <- Keyword.get(opts, key),
         nil <- Application.get_env(:exvalibur, key),
         [{me, _, _} | _] = Application.started_applications(),
         nil <- Application.get_env(me, :exvalibur, %{})[key],
         do: Module.concat([Macro.camelize(to_string(me)), "Exvalibur", fallback])
  end

  @spec rules_to_map(rules :: list()) :: map()
  defp rules_to_map(rules) when is_list(rules) do
    for rule <- rules,
        do: {:erlang.term_to_binary(rule), rule},
        into: %{}
  end

  @spec reducer(map(), acc :: list()) :: list()
  defp reducer(%{matches: matches, conditions: conditions}, acc) do
    matches_and_conditions =
      {:%{}, [],
       conditions
       |> Map.keys()
       |> Enum.map(&{&1, Macro.var(&1, __MODULE__)})
       |> Kernel.++(Map.to_list(matches))}

    guards =
      for {var, guards} <- conditions, {guard, val} <- guards do
        unless Exvalibur.Guards.guard?(guard),
          do: raise(Exvalibur.Error, reason: %{unknown_guard: guard})

        Exvalibur.Guards.guard!(guard, __MODULE__, var, val)
      end
      |> Enum.reduce([], fn
        guard, [] ->
          guard

        guard, ast ->
          {:and, [context: Elixir, import: Kernel], [ast, guard]}
      end)

    [
      quote do
        def valid?(unquote(matches_and_conditions))
            when unquote(guards),
            do: {:ok, unquote(matches_and_conditions)}
      end
      | acc
    ]
  end

  @spec transformer(rules :: list(), :flow | :enum) :: list()
  defp transformer(rules, :flow) do
    rules
    |> Flow.from_enumerable()
    |> Flow.reduce(fn -> [] end, &reducer/2)
    |> Enum.to_list()
  end

  defp transformer(rules, :enum) do
    Enum.reduce(rules, [], &reducer/2)
  end

  @spec ast(rules :: list(), current_rules :: map(), processor :: :flow | :enum) :: list()
  defp ast(rules, current_rules, processor)
       when is_list(rules) and is_map(current_rules) do
    # the latter takes precedence
    rules = Map.merge(current_rules, rules_to_map(rules))

    [
      quote do
        import Exvalibur.Guards
      end
      | rules
        |> Map.values()
        |> transformer(processor)
        |> Kernel.++([
          quote do
            def valid?(_), do: :error
            def rules(), do: unquote(Macro.escape(rules))
          end
        ])
    ]
  end
end
