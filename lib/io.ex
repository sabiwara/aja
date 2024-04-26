defmodule Aja.IO do
  @moduledoc false

  @deprecated "Use the :ion library instead (https://hex.pm/packages/ion)"
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

  @deprecated "Use the :ion library instead (https://hex.pm/packages/ion)"
  @compile {:inline, to_iodata: 1}
  @spec to_iodata(String.Chars.t() | iodata | IO.chardata()) :: iodata | IO.chardata()
  def to_iodata(data) when is_list(data) or is_binary(data) do
    data
  end

  def to_iodata(data) do
    String.Chars.to_string(data)
  end
end
