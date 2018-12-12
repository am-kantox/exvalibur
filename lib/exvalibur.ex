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

  One should privide at least one match or condition:

      iex> rules = [%{matches: %{currency_pair: "EURUSD"}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.MatchValidator)
      ...> Exvalibur.MatchValidator.valid?(%{currency_pair: "EURUSD", rate: 1.5})
      {:ok, %{currency_pair: "EURUSD"}}

      iex> rules = [%{conditions: %{rate: %{eq: 1.5}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.ConditionValidator)
      ...> Exvalibur.ConditionValidator.valid?(%{currency_pair: "EURGBP", rate: 1.5})
      {:ok, %{rate: 1.5}}

      iex> rules = [%{foo: :bar}]
      ...> try do
      ...>   Exvalibur.validator!(rules, module_name: Exvalibur.RaisingValidator)
      ...> rescue
      ...>   e in [Exvalibur.Error] ->
      ...>   e.reason
      ...> end
      %{empty_rule: %{foo: :bar}}
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
      ...>   Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
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
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator, merge: false)
      ...> Exvalibur.Validator.valid?(%{currency_pair: "EURGBP", any: 42, rate: 1.5, source: "FOO"})
      {:ok, %{currency_pair: "EURGBP", rate: 1.5, source: "FOO"}}
      iex> Exvalibur.Validator.valid?(%{currency_pair: "EURUSD", any: 42, rate: 1.5, source: "BAH"})
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

  @known_fields ~w|matches conditions guards|a

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
  defp reducer(%{matches: matches, conditions: conditions, guards: guards}, acc)
       when is_map(matches) and is_binary(conditions) and is_map(guards) and is_list(acc) do
    conditions =
      conditions
      |> Code.string_to_quoted!()
      |> Exvalibur.Guards.guards_module().traverse_conditions()

    reducer(%{matches: matches, conditions: conditions, guards: guards}, acc)
  end

  defp reducer(%{matches: matches, conditions: conditions, guards: guards}, acc)
       when is_map(matches) and is_map(conditions) and is_map(guards) and is_list(acc) do
    matches_and_conditions_keys = Map.keys(conditions)

    matches_and_conditions =
      {:%{}, [],
       matches_and_conditions_keys
       |> Enum.reduce(matches, &Map.put_new(&2, &1, Macro.var(&1, __MODULE__)))
       |> Map.to_list()}

    matches_and_conditions_keys = matches_and_conditions_keys ++ Map.keys(matches)

    conditional_guards =
      for {var, conditional_guards} <- conditions, {guard, val} <- conditional_guards do
        unless Exvalibur.Guards.guard?(guard),
          do: raise(Exvalibur.Error, reason: %{unknown_guard: guard})

        Exvalibur.Guards.guard!(guard, __MODULE__, var, val)
      end

    conditional_guards =
      guards
      |> Enum.reduce(conditional_guards, fn {_name, guard}, conditional_guards ->
        [guard_to_ast(guard) | conditional_guards]
      end)
      |> Enum.reduce([], fn
        guard, [] ->
          guard

        guard, ast ->
          {:and, [context: Elixir, import: Kernel], [ast, guard]}
      end)

    [
      case conditional_guards do
        [] ->
          quote do
            def valid?(unquote(matches_and_conditions) = input),
              do: {:ok, Map.take(input, unquote(matches_and_conditions_keys))}
          end

        _ ->
          quote do
            def valid?(unquote(matches_and_conditions) = input)
                when unquote(conditional_guards),
                do: {:ok, Map.take(input, unquote(matches_and_conditions_keys))}
          end
      end
      | acc
    ]
  end

  defp reducer(%{guards: guards} = matches_conditions_guards, acc)
       when is_binary(guards) and is_list(acc) do
    reducer(%{matches_conditions_guards | guards: [guards]}, acc)
  end

  defp reducer(%{guards: guards} = matches_conditions_guards, acc)
       when is_list(guards) and is_list(acc) do
    guards =
      guards
      |> Enum.with_index(1)
      |> Enum.into(%{}, fn {guard, i} -> {:"guard_#{i}", guard} end)

    reducer(%{matches_conditions_guards | guards: guards}, acc)
  end

  defp reducer(matches_conditions_guards, acc)
       when is_map(matches_conditions_guards) and is_list(acc) do
    matches_conditions_guards_empty? =
      Enum.reduce(@known_fields, true, &(&2 and empty?(matches_conditions_guards[&1])))

    if matches_conditions_guards_empty?,
      do: raise(Exvalibur.Error, reason: %{empty_rule: matches_conditions_guards})

    matches_conditions_guards =
      Enum.reduce(@known_fields, matches_conditions_guards, &Map.put_new(&2, &1, %{}))

    reducer(matches_conditions_guards, acc)
  end

  @spec empty?(group :: nil | binary() | map()) :: true | false
  def empty?(nil), do: true
  def empty?(map) when is_map(map) and map_size(map) == 0, do: true
  def empty?(string) when is_binary(string) and byte_size(string) == 0, do: true
  def empty?(_), do: false

  @spec guard_to_ast(guard :: binary() | tuple()) :: any()
  def guard_to_ast(string) when is_binary(string),
    do: Code.string_to_quoted!(string)

  def guard_to_ast({_, _, _} = ast), do: ast

  @spec transformer(rules :: list(), :flow | :enum) :: list()
  defp transformer(rules, :flow) when is_list(rules) do
    rules
    |> Flow.from_enumerable()
    |> Flow.reduce(fn -> [] end, &reducer/2)
    |> Enum.to_list()
  end

  defp transformer(rules, :enum) when is_list(rules),
    do: Enum.reduce(rules, [], &reducer/2)

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
            def rules, do: unquote(Macro.escape(rules))
          end
        ])
    ]
  end
end
