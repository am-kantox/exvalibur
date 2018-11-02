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
  end

  @guards_module Application.get_env(:exvalibur, :guards, __MODULE__.Default)
  @guards :functions
          |> @guards_module.__info__()
          |> Enum.filter(&(elem(&1, 1) == 2))
          |> Keyword.keys()

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
