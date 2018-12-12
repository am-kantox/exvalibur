defmodule Exvalibur.Guards do
  @moduledoc false
  defmodule Default do
    @moduledoc """
    Default set of guards to be used with `Exvalibur.validator!/2`.

    Guards are public functions of arity 2, exporting the AST valid as Elixir guard.
    One might provide their own set of guards by the following config:

        config :exvalibur, :guards, MyApp.Guards

    Assuming that the file itself looks somewhat like:

        defmodule MyApp.Guards do
          import Exvalibur.Guards.Default, except: [min_length: 2]

          def min_length(var, val) when is_integer(val) do
            quote do
              is_bitstring(unquote(var)) and bytesize(unquote(var)) >= unquote(val)
            end
          end
        end
    """

    @doc "Guard for conditions like `%{min: 1.0}`, implies actual value is greater or equal than the parameter"
    @spec min(any(), number()) :: {:and, list(), list()}
    def min(var, val) when is_number(val),
      do: quote(do: is_number(unquote(var)) and unquote(var) >= unquote(val))

    @doc "Guard for conditions like `%{max: 2.0}`, implies actual value is less or equal than the parameter"
    @spec max(any(), number()) :: {:and, list(), list()}
    def max(var, val) when is_number(val),
      do: quote(do: is_number(unquote(var)) and unquote(var) <= unquote(val))

    @doc "Guard for conditions like `%{less_than: 1.0}`, like `max/2`, but the inequality is strict"
    @spec less_than(any(), number()) :: {:and, list(), list()}
    def less_than(var, val) when is_number(val),
      do: quote(do: is_number(unquote(var)) and unquote(var) < unquote(val))

    @doc "Guard for conditions like `%{greater_than: 1.0}`, like `min/2`, but the inequality is strict"
    @spec greater_than(any(), number()) :: {:and, list(), list()}
    def greater_than(var, val) when is_number(val),
      do: quote(do: is_number(unquote(var)) and unquote(var) > unquote(val))

    @doc "Guard for conditions like `%{eq: 1.0}`, exact equality"
    @spec eq(any(), number()) :: {:and, list(), list()}
    def eq(var, val) when is_number(val),
      do: quote(do: is_number(unquote(var)) and unquote(var) == unquote(val))

    @doc "Guard for checking the includion in the list like `%{one_of: [42, 3.14]}`"
    @spec one_of(any(), list()) :: {:in, list(), list()}
    def one_of(var, val) when is_list(val),
      do: quote(do: unquote(var) in unquote(val))

    @doc "Guard for checking the excludion from the list like `%{not_one_of: [42, 3.14]}`"
    @spec not_one_of(any(), list()) :: {:not, list(), [{:in, list(), list()}]}
    def not_one_of(var, val) when is_list(val),
      do: quote(do: unquote(var) not in unquote(val))

    @doc "Guard for conditions like `%{min_length: 10}`, checks the byte length of the binary parameter"
    @spec min_length(any(), integer()) :: {:and, list(), list()}
    def min_length(var, val) when is_integer(val),
      do: quote(do: is_bitstring(unquote(var)) and bytesize(unquote(var)) >= unquote(val))

    @doc "Guard for conditions like `%{max_length: 10}`, checks the byte length of the binary parameter"
    @spec max_length(any(), integer()) :: {:and, list(), list()}
    def max_length(var, val) when is_integer(val),
      do: quote(do: is_bitstring(unquote(var)) and bytesize(unquote(var)) <= unquote(val))

    @doc "Guard for conditions like `%{min_count: 10}`, checks the number of elements in list parameter"
    @spec min_count(any(), integer()) :: {:and, list(), list()}
    def min_count(var, val) when is_integer(val),
      do: quote(do: is_list(unquote(var)) and length(unquote(var)) >= unquote(val))

    @doc "Guard for conditions like `%{max_count: 10}`, checks the number of elements in list parameter"
    @spec max_count(any(), integer()) :: {:and, list(), list()}
    def max_count(var, val) when is_integer(val),
      do: quote(do: is_list(unquote(var)) and length(unquote(var)) <= unquote(val))

    ############################################################################

    @doc "Multi-clause function to convert binary representation to guard"
    @spec traverse_conditions(ast :: any(), acc :: map()) :: map()
    def traverse_conditions(ast, acc \\ %{})

    def traverse_conditions({:and, _, ast}, acc) when is_list(ast) do
      Enum.reduce(ast, acc, &traverse_conditions/2)
    end

    def traverse_conditions({:or, _, _}, _),
      do: raise(Exvalibur.Error, reason: %{not_yet_supported: :or_clause})

    def traverse_conditions({:>=, _, [{var, _, _}, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{min: value}}
               %{} = map -> {map, Map.put(map, :min, value)}
             end),
           do: result
    end

    def traverse_conditions({:<=, _, [{var, _, _}, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{max: value}}
               %{} = map -> {map, Map.put(map, :max, value)}
             end),
           do: result
    end

    def traverse_conditions({:<, _, [{var, _, _}, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{less_than: value}}
               %{} = map -> {map, Map.put(map, :less_than, value)}
             end),
           do: result
    end

    def traverse_conditions({:>, _, [{var, _, _}, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{greater_than: value}}
               %{} = map -> {map, Map.put(map, :greater_than, value)}
             end),
           do: result
    end

    def traverse_conditions({:=, _, [{var, _, _}, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{eq: value}}
               %{} = map -> {map, Map.put(map, :eq, value)}
             end),
           do: result
    end

    def traverse_conditions({:==, meta, ast}, acc),
      do: traverse_conditions({:=, meta, ast}, acc)

    def traverse_conditions({:in, _, [var, value]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{one_of: value}}
               %{} = map -> {map, Map.put(map, :one_of, value)}
             end),
           do: result
    end

    def traverse_conditions({:not, _, [{:in, _, [var, value]}]}, acc) do
      with {_, result} <-
             Map.get_and_update(acc, var, fn
               nil -> {nil, %{not_one_of: value}}
               %{} = map -> {map, Map.put(map, :not_one_of, value)}
             end),
           do: result
    end
  end

  @guards_module Application.get_env(:exvalibur, :guards, __MODULE__.Default)
  @guards :functions
          |> @guards_module.__info__()
          |> Enum.filter(&(elem(&1, 1) == 2))
          |> Keyword.keys()

  @doc false
  @spec guards_module() :: atom()
  def guards_module, do: @guards_module

  @doc false
  @spec guards() :: [atom()]
  def guards, do: @guards

  @doc false
  @spec guard?(any()) :: boolean()
  def guard?(guard), do: is_atom(guard) and Enum.any?(@guards, &(&1 == guard))

  @doc false
  @spec guard!(atom(), atom(), atom(), any()) :: {:and | :in | :not | :or, list(), list()}
  def guard!(name, mod, var, val) when is_atom(var) do
    apply(@guards_module, name, [Macro.var(var, mod), val])
  end
end
