defmodule Exvalibur.Error do
  @moduledoc """
  An exception to be thrown for inconsistent attempt to create a validator instance.
  """

  defexception [:reason, :message]

  @doc false
  def exception(reason: %{unknown_guard: guard} = reason) do
    message = """
      Unknown guard #{guard} in call to `Exvalibur.validator!/2`.

      Allowed guards:
        #{Exvalibur.Guards.guards() |> Enum.join(", ")}

      If you need to define your own guards, set `config :exvalibur, :guards, MyGuards`
      and implement one or more functions of arity 2, returning proper guard AST
      in `MyGuards` module, like:

          defmodule MyApp.Guards do
            import Exvalibur.Guards.Default, except: [min_length: 2]

            def min_length(var, val) when is_integer(val) do
              quote do
                is_bitstring(unquote(var)) and bytesize(unquote(var)) >= unquote(val)
              end
            end
          end
    """

    %Exvalibur.Error{message: message, reason: reason}
  end
end
