defmodule Exvalibur.Sigils do
  def sigil_V(string, []), do: Code.string_to_quoted!(string)
end
