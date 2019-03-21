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
  with as many clauses of `validate/1` function as we have rules above (plus one
  handling-all clause.) Once generated, the `validate/1` function of the module
  generated might be called directly on the input data, providing blazingly fast
  validation based completely on pattern matching and guards.

  One should privide at least one match or condition:

      iex> rules = [%{matches: %{currency_pair: "EURUSD"}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.MatchValidator)
      ...> Exvalibur.MatchValidator.validate(%{currency_pair: "EURUSD", rate: 1.5})
      {:ok, %{currency_pair: "EURUSD"}}

      iex> rules = [%{conditions: %{rate: %{eq: 1.5}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.ConditionValidator)
      ...> Exvalibur.ConditionValidator.validate(%{currency_pair: "EURGBP", rate: 1.5})
      {:ok, %{rate: 1.5}}

      iex> rules = [%{foo: :bar}]
      ...> try do
      ...>   Exvalibur.validator!(rules, module_name: Exvalibur.RaisingValidator)
      ...> rescue
      ...>   e in [Exvalibur.Error] ->
      ...>   e.reason
      ...> end
      %{empty_rule: %{foo: :bar}}

  `Exvalibur.validator!/2` Produces the validator module given the set of rules.

  ## Options

  - `module_name :: binary()` the name of the module to produce; when omitted, it will be looked up in current application options
  - `merge :: boolean()` when true, the existing rules are taken from the module (if exists) and being merged against current rules
  - `flow :: boolean()` when true, the underlying module generator uses [`Flow`](https://hexdocs.pm/flow) to process an input

  ## Example

      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURUSD"},
      ...>     conditions: %{rate: %{min: 1.0, max: 2.0}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
      ...> Exvalibur.Validator.validate(%{currency_pair: "EURUSD", rate: 1.5})
      {:ok, %{currency_pair: "EURUSD", rate: 1.5}}
      iex> Exvalibur.Validator.validate(%{currency_pair: "EURGBP", rate: 1.5})
      :error
      iex> Exvalibur.Validator.validate(%{currency_pair: "EURUSD", rate: 0.5})
      :error
      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURGBP"},
      ...>     conditions: %{rate: %{min: 1.0, max: 2.0}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator)
      ...> Exvalibur.Validator.validate(%{currency_pair: "EURGBP", rate: 1.5})
      {:ok, %{currency_pair: "EURGBP", rate: 1.5}}
      iex> Exvalibur.Validator.validate(%{currency_pair: "EURUSD", rate: 1.5})
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

  Generated `validate/1` function returns either `:error` or `{:ok, map()}`.
  In a case of successful validation, the map contained values _that were indeed validated_.
  Note that in the following example the value for `any` key is not returned.

      iex> rules = [
      ...>   %{matches: %{currency_pair: "EURGBP"},
      ...>     conditions: %{
      ...>       rate: %{min: 1.0, max: 2.0},
      ...>       source: %{one_of: ["FOO", "BAR"]}}}]
      ...> Exvalibur.validator!(rules, module_name: Exvalibur.Validator, merge: false)
      ...> Exvalibur.Validator.validate(%{currency_pair: "EURGBP", any: 42, rate: 1.5, source: "FOO"})
      {:ok, %{currency_pair: "EURGBP", rate: 1.5, source: "FOO"}}
      iex> Exvalibur.Validator.validate(%{currency_pair: "EURUSD", any: 42, rate: 1.5, source: "BAH"})
      :error

  ## Module-based validators

      iex> defmodule Validator do
      ...>   use Exvalibur, rules: [
      ...>     %{
      ...>       matches: %{currency_pair: <<"EUR", _ :: binary>>},
      ...>       conditions: %{foo: %{min: 0, max: 100}},
      ...>       guards: %{num: num > 0 and num < 100}}]
      ...> end
      iex> Validator.validate(%{currency_pair: "EURUSD", foo: 50, num: 50})
      {:ok, %{currency_pair: "EURUSD", foo: 50, num: 50}}
      iex> Validator.validate(%{currency_pair: "USDEUR", foo: 50, num: 50})
      :error
      iex> Validator.validate(%{currency_pair: "EURUSD", foo: -50, num: 50})
      :error
      iex> Validator.validate(%{currency_pair: "EURUSD", foo: 50, num: -50})
      :error
  """

  @known_fields ~w|matches conditions guards|a

  import Exvalibur.Sigils

  @doc false
  defmacro __using__(opts), do: do_using(opts)

  @spec do_using(opts :: Keyword.t()) :: term()
  defp do_using(rules: rules), do: do_using(rules: rules, flow: :enum)

  # [{:%{}, [line: 108],
  #   [matches: {:%{}, [line: 109],
  #      [currency_pair: {:<<>>, [line: 109], ["EUR", {:::, [line: 109],
  #         [{:_, [line: 109], nil}, {:binary, [line: 109], nil}]}]}]},
  #    conditions: {:%{}, [line: 110],
  #      [foo: {:%{}, [line: 110], [min: 0, max: 100]}]},
  #    guards: {:and, [line: 111],
  #      [{:>, [line: 111], [{:num, [line: 111], nil}, 0]},
  #       {:<, [line: 111], [{:num, [line: 111], nil}, 100]}]}]}]
  defp do_using(rules: rules, flow: flow) when is_list(rules) and flow in [:enum, :flow] do
    new_rules =
      rules
      |> Enum.map(fn
        {:%{}, _, rule} ->
          rule
          |> Enum.into(%{})
          |> do_using_clause(:matches, fn {k, v} -> {k, ~q[#{Macro.to_string(v)}]} end)
          |> do_using_clause(:conditions, fn {k, {:%{}, _, vals}} ->
            {k, Enum.into(vals, %{})}
          end)
          |> do_using_clause(:guards, fn {k, guard} -> {k, Macro.to_string(guard)} end)
          |> do_using_update_guards()
      end)
      |> MapSet.new()

    ast(new_rules, flow)
  end

  @spec do_using_clause(
          map :: map(),
          key :: :matches | :conditions | :guards,
          (tuple() -> tuple())
        ) :: map()
  defp do_using_clause(map, key, mapper)
       when is_map(map) and is_atom(key) and key in @known_fields do
    map
    |> get_and_update_in([key], fn
      nil ->
        :pop

      {:%{}, _, list} = old when is_list(list) ->
        {old, Enum.into(list, %{}, mapper)}
    end)
    |> elem(1)
  end

  @spec do_using_update_guards(map :: map()) :: map()
  defp do_using_update_guards(%{guards: guards} = map)
       when is_map(guards) and map_size(guards) > 0 do
    guards
    |> Map.keys()
    |> Enum.reduce(map, fn guard, acc ->
      acc
      |> get_and_update_in([:matches], fn
        nil -> {nil, %{guard => ~q[#{guard}]}}
        %{} = map -> {map, Map.put(map, guard, ~q[#{guard}])}
      end)
      |> elem(1)
    end)
  end

  defp do_using_update_guards(map), do: map

  @spec validator!(rules :: list() | MapSet.t(), opts :: list()) ::
          {:module, module(), binary(), term()}
  def validator!(rules, opts)

  def validator!(rules, opts) when is_list(rules) and is_list(opts),
    do: validator!(MapSet.new(rules), opts)

  def validator!(%MapSet{} = rules, opts) when is_list(opts) do
    name = get_or_create_module_name(opts, :module_name, "Instance")
    merge = Keyword.get(opts, :merge, true)
    processor = if opts[:flow], do: :flow, else: :enum

    new_rules =
      MapSet.union(
        rules,
        MapSet.new(
          if Code.ensure_compiled?(name) do
            cr = if merge, do: apply(name, :rules, [])
            :code.purge(name)
            :code.delete(name)
            cr
          end || []
        )
      )

    Module.create(name, ast(new_rules, processor), Macro.Env.location(__ENV__))
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
        guard, [] -> guard
        guard, ast -> {:and, [context: Elixir, import: Kernel], [ast, guard]}
      end)
      |> reduce_guards_clause(matches_and_conditions, matches_and_conditions_keys)

    [conditional_guards | acc]
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

  @spec reduce_guards_clause(
          guards :: list(),
          matches_and_conditions :: tuple(),
          matches_and_conditions_keys :: list()
        ) :: tuple()
  defp reduce_guards_clause([], matches_and_conditions, matches_and_conditions_keys) do
    quote do
      @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
      def validate(unquote(matches_and_conditions) = mâp),
        do: {:ok, Map.take(mâp, unquote(matches_and_conditions_keys))}
    end
  end

  defp reduce_guards_clause(guards, matches_and_conditions, matches_and_conditions_keys) do
    quote do
      @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
      def validate(unquote(matches_and_conditions) = mâp) when unquote(guards),
        do: {:ok, Map.take(mâp, unquote(matches_and_conditions_keys))}
    end
  end

  @spec empty?(group :: nil | binary() | map()) :: true | false
  defp empty?(nil), do: true
  defp empty?(map) when is_map(map) and map_size(map) == 0, do: true
  defp empty?(string) when is_binary(string) and byte_size(string) == 0, do: true
  defp empty?(_), do: false

  @spec guard_to_ast(guard :: binary() | tuple()) :: any()
  defp guard_to_ast(string) when is_binary(string), do: Code.string_to_quoted!(string)
  defp guard_to_ast({_, _, _} = ast), do: ast

  @spec transformer(rules :: MapSet.t(), :flow | :enum) :: list()
  defp transformer(%MapSet{} = rules, :flow) do
    rules
    |> Flow.from_enumerable()
    |> Flow.reduce(fn -> [] end, &reducer/2)
    |> Enum.to_list()
  end

  defp transformer(%MapSet{} = rules, :enum),
    do: Enum.reduce(rules, [], &reducer/2)

  @spec ast(rules :: MapSet.t(), processor :: :flow | :enum) :: list()
  defp ast(%MapSet{map: rules}, _) when map_size(rules) == 0 do
    quote do
      @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
      def validate(any), do: {:ok, any}
      @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
      @deprecated "Use #{__MODULE__}.validate/1 instead"
      def valid?(any), do: validate(any)
      @doc "The ruleset to validate an input against"
      def rules, do: []
    end
  end

  defp ast(%MapSet{} = rules, processor) do
    [
      quote do
        import Exvalibur.Guards
      end
      | rules
        |> transformer(processor)
        |> Kernel.++([
          quote do
            @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
            def validate(_), do: :error
            @doc "Validates the input against rules. See #{__MODULE__}.rules/0"
            @deprecated "Use #{__MODULE__}.validate/1 instead"
            def valid?(any), do: validate(any)
            @doc "The ruleset to validate an input against"
            def rules, do: unquote(Macro.escape(MapSet.to_list(rules)))
          end
        ])
    ]
  end
end
