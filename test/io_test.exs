defmodule Aja.IOTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Aja.IO

  @tag timeout: :infinity
  @tag :property
  property "iodata_empty?/1 is always consistent with IO.iodata_length/1" do
    check all(data <- iodata()) do
      zero_length? = IO.iodata_length(data) == 0

      assert zero_length? == Aja.IO.iodata_empty?(data)
    end
  end
end
