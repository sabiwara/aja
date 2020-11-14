defmodule A.IO do
  @moduledoc ~S"""
  Some extra helper functions for working with IO data,
  that are not in the core `IO` module.
  """

  # TODO: Link about cowboy/mint, benchmarks with Jason
  # TODO bench then inline

  @doc ~S"""
  Checks if IO data is empty in "constant" time.

  Should only need to loop until it finds one character or binary to stop,
  unlike `IO.iodata_length(iodata) == 0` which needs to perform the complete loop
  to compute the length first.

  ## Examples

      iex> A.IO.iodata_empty?(["", []])
      true
      iex> A.IO.iodata_empty?('a')
      false
      iex> A.IO.iodata_empty?(["a"])
      false
      iex> A.IO.iodata_empty?(["", [], ["" | "c"]])
      false

  ## Rationale

  Even if `IO.iodata_length/1` is a very efficient BIF implemented in C, it has a linear
  algorithmic complexity and can become slow if invoked on an IO list with many elements.

  This is not a far-fetched scenario, and a production use case can easily include
  "big" IO-lists with:
  - JSON encoding to IO-data of long lists / nested objects
  - loops within HTML templates

  """
  @compile {:inline, iodata_empty?: 1}
  @spec iodata_empty?(iodata) :: boolean
  def iodata_empty?(iodata) when is_binary(iodata) or is_list(iodata) do
    iodata_empty?(iodata, [])
  end

  @compile {:inline, iodata_empty?: 2}
  # empty-case: depends what is left to check
  defp iodata_empty?(iodata, to_check) when iodata in ["", []] do
    case to_check do
      [] -> true
      [head | tail] -> iodata_empty?(head, tail)
    end
  end

  # non-empty binary or
  defp iodata_empty?(binary, _) when is_binary(binary), do: false
  defp iodata_empty?([head | _], _) when is_integer(head), do: false

  # the head is neither a binary nor a string: it must be an iolist. check the head now, the tail later
  defp iodata_empty?([head | tail], acc), do: iodata_empty?(head, [tail | acc])

  @doc """
  Converts the argument to IO data according to the `String.Chars` protocol.

  Leaves lists untouched, calls `to_string/1` on everything else.

  This is the function invoked in string interpolations within the [i sigil](`A.sigil_i/2`).

  ## Examples

      iex> A.IO.to_iodata(:foo)
      "foo"
      iex> A.IO.to_iodata(99)
      "99"
      iex> A.IO.to_iodata(["abc", 'def' | "ghi"])
      ["abc", 'def' | "ghi"]

  """
  @compile {:inline, to_iodata: 1}
  @spec to_iodata(String.Chars.t()) :: iodata
  def to_iodata(data) when is_list(data) do
    data
  end

  def to_iodata(data) do
    to_string(data)
  end
end
