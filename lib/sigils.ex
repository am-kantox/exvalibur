defmodule Exvalibur.Sigils do
  @moduledoc """
  Implementation of sigils `~q` and `~Q` to allow patterns inside `matches` in `rules`.

  Import this module to get an access to sigils.
  """

  @doc ~S"""
  Handles the sigil `~Q` for non-interpolated match expressions.

  It returns an AST that might be used as is in `Exvalibur.validator!/2`’s rules.

  ## Examples
      iex> import Exvalibur.Sigils
      iex> ~Q[%{} = _]
      {:=, [line: 15], [{:%{}, [line: 15], []}, {:_, [line: 15], nil}]}
      iex> ~Q[<<"foo", _ :: binary>>]
      {:<<>>, [line: 14],
        ["foo", {:::, [line: 14], [{:_, [line: 14], nil}, {:binary, [line: 14], nil}]}]}
      iex> ~Q[<<invalid]
      ** (TokenMissingError) nofile:14: missing terminator: >> (for "<<" starting at line 14)
  """
  @spec sigil_Q(term :: binary(), modifiers :: list()) :: any()
  defmacro sigil_Q(term, modifiers)

  defmacro sigil_Q({:<<>>, meta, [string]}, []) when is_binary(string) do
    quote bind_quoted: [string: string, meta: meta] do
      Code.string_to_quoted!(string, meta)
    end
  end

  @doc ~S"""
  Handles the sigil `~q` for interpolated match expressions.

  It behaves exactly as `sigil_Q` save for it interpolates the string passed to sigil.
  """
  @spec sigil_q(term :: binary(), modifiers :: list()) :: any()
  defmacro sigil_q(term, modifiers)

  defmacro sigil_q({:<<>>, meta, [string]}, []) when is_binary(string) do
    quote bind_quoted: [string: string, meta: meta] do
      string
      |> :elixir_interpolation.unescape_chars()
      |> Code.string_to_quoted!(meta)
    end
  end

  defmacro sigil_q({:<<>>, meta, pieces}, []) do
    tokens =
      case :elixir_interpolation.unescape_tokens(pieces) do
        {:ok, unescaped_tokens} -> unescaped_tokens
        {:error, reason} -> raise ArgumentError, to_string(reason)
      end

    quote do
      Code.string_to_quoted!(unquote({:<<>>, meta, tokens}), unquote(meta))
    end
  end
end
