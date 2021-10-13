defmodule Aja.IO do
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

      iex> Aja.IO.iodata_empty?(["", []])
      true
      iex> Aja.IO.iodata_empty?('a')
      false
      iex> Aja.IO.iodata_empty?(["a"])
      false
      iex> Aja.IO.iodata_empty?(["", [], ["" | "c"]])
      false

  ## Rationale

  Even if `IO.iodata_length/1` is a very efficient BIF implemented in C, it has a linear
  algorithmic complexity and can become slow if invoked on an IO list with many elements.

  This is not a far-fetched scenario, and a production use case can easily include
  "big" IO-lists with:
  - JSON encoding to IO-data of long lists / nested objects
  - loops within HTML templates

  """
  @spec iodata_empty?(iodata) :: boolean
  def iodata_empty?(iodata)

  def iodata_empty?(binary) when is_binary(binary), do: binary === ""
  def iodata_empty?([]), do: true
  def iodata_empty?([head | _]) when is_integer(head), do: false

  def iodata_empty?([head | rest]) do
    # optimized `and`
    case iodata_empty?(head) do
      false -> false
      _ -> iodata_empty?(rest)
    end
  end

  @doc """
  Converts the argument to IO data according to the `String.Chars` protocol.

  Leaves lists untouched without any validation, calls `to_string/1` on everything else.

  This is the function invoked in string interpolations within the [i sigil](`Aja.sigil_i/2`).

  Works with both [IO data](https://hexdocs.pm/elixir/IO.html#module-io-data) and
  [Chardata](https://hexdocs.pm/elixir/IO.html?#module-chardata),
  depending on the type of the `data` parameter.

  ## Examples

      iex> Aja.IO.to_iodata(:foo)
      "foo"
      iex> Aja.IO.to_iodata(99)
      "99"
      iex> Aja.IO.to_iodata(["abc", 'def' | "ghi"])
      ["abc", 'def' | "ghi"]

  """
  @compile {:inline, to_iodata: 1}
  @spec to_iodata(String.Chars.t() | iodata | IO.chardata()) :: iodata | IO.chardata()
  def to_iodata(data) when is_list(data) or is_binary(data) do
    data
  end

  def to_iodata(data) do
    String.Chars.to_string(data)
  end
end
