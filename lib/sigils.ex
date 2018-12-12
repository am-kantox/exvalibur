defmodule Exvalibur.Sigils do
  defmacro sigil_V({:<<>>, meta, [string]}, []) when is_binary(string) do
    quote bind_quoted: [string: string, meta: meta] do
      Code.string_to_quoted!(string, meta)
    end
  end

  defmacro sigil_v(term, modifiers)

  defmacro sigil_v({:<<>>, meta, [string]}, []) when is_binary(string) do
    quote bind_quoted: [string: string, meta: meta] do
      string
      |> :elixir_interpolation.unescape_chars()
      |> Code.string_to_quoted!(meta)
    end
  end

  defmacro sigil_v({:<<>>, meta, pieces}, []) do
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
