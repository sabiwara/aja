defmodule A.ExRange.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A, only: [~>: 2]

  @moduletag timeout: :infinity
  @moduletag :property

  property "should be consistent for any integer" do
    check all(
            start <- integer(),
            stop <- integer()
          ) do
      range = start ~> stop
      assert ^range = A.ExRange.new(start, stop)

      expected_length = abs(stop - start)
      list = Enum.to_list(range)
      assert expected_length == Enum.count(range)
      assert expected_length == A.Enum.count(range)
      assert expected_length == length(list)

      expected_empty = expected_length == 0
      assert expected_empty === Enum.empty?(range)
      assert expected_empty === A.Enum.empty?(range)

      refute (max(start, stop) + 1) in range
      refute (min(start, stop) - 1) in range
      refute stop in range
      refute stop in list
      assert Enum.all?(list, fn i -> i in range end)
      assert Enum.all?(range, fn i -> i in list end)
      assert list == Enum.slice(range, 0..expected_length)
      assert list == Enum.slice(range, -expected_length..-1)
    end
  end
end
