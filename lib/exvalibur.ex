defmodule Exvalibur do
  @moduledoc """
  `Exvalibur` is the generator for blazingly fast validators of maps based on sets of predefined rules.
  """

  @doc """
  Produces the validator module given the set of rules.

  ## Options

  - `module_name :: binary()` the name of the module to produce; when omitted, it will be looked up in current application options
  - `merge :: boolean` when true, the existing rules are taken from the module (if exists) and being merged against current rules

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

    Module.create(name, ast(rules, current_rules), Macro.Env.location(__ENV__))
  end

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

  @spec keyify({k :: any(), v :: any()}) :: binary()
  defp keyify({k, v}) do
    [k, v]
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.join()
  end

  @spec rules_to_map(rules :: list()) :: map()
  defp rules_to_map(rules) when is_list(rules) do
    for %{matches: matches} = rule <- rules,
        do: {for({k, v} <- matches, do: keyify({k, v}), into: <<>>), rule},
        into: %{}
  end

  @spec ast(rules :: list(), current_rules :: map()) :: list()
  defp ast(rules, current_rules) when is_list(rules) and is_map(current_rules) do
    # the latter takes precedence
    rules = Map.merge(current_rules, rules_to_map(rules))

    [
      quote do
        import Exvalibur.Guargs
      end
      | rules
        |> Map.values()
        |> Enum.map(fn %{matches: matches, conditions: conditions} ->
          matches_and_conditions =
            {:%{}, [],
             conditions
             |> Map.keys()
             |> Enum.map(&{&1, Macro.var(&1, __MODULE__)})
             |> Kernel.++(Map.to_list(matches))}

          guards =
            for {var, guards} <- conditions, {guard, val} <- guards do
              Exvalibur.Guargs.guard!(guard, __MODULE__, var, val)
            end
            |> Enum.reduce([], fn
              guard, [] ->
                guard

              guard, ast ->
                {:and, [context: Elixir, import: Kernel], [ast, guard]}
            end)

          quote do
            def valid?(unquote(matches_and_conditions))
                when unquote(guards),
                do: {:ok, unquote(matches_and_conditions)}
          end
        end)
        |> Kernel.++([
          quote do
            def valid?(_), do: :error
            def rules(), do: unquote(Macro.escape(rules))
          end
        ])
    ]
  end
end
