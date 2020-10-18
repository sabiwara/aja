defmodule A.ExRangeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A, only: [{:~>, 2}]

  doctest A.ExRange

  test "new/2 validation errors" do
    assert_raise ArgumentError,
                 "A.ExRange (start ~> stop) expect both sides to be integers, got: :zero ~> 10",
                 fn -> A.ExRange.new(:zero, 10) end

    assert_raise ArgumentError,
                 "A.ExRange (start ~> stop) expect both sides to be integers, got: 0 ~> '10'",
                 fn -> A.ExRange.new('10') end

    assert_raise ArgumentError,
                 "A.ExRange (start ~> stop) expect both sides to be integers, got: \"0\" ~> \"10\"",
                 fn -> "0" ~> "10" end
  end

  test "Enum.to_list/1" do
    assert [] = Enum.to_list(0 ~> 0)
    assert [1] = Enum.to_list(1 ~> 2)
    assert [1] = Enum.to_list(1 ~> 0)
    assert [0, 1, 2, 3, 4, 5, 6] = Enum.to_list(0 ~> 7)
  end

  test "Enum.member?/2" do
    assert false == Enum.member?(0 ~> 0, 0)
    assert true == Enum.member?(1 ~> 2, 1)
    assert false == Enum.member?(1 ~> 2, 2)
    assert true == Enum.member?(1 ~> 0, 1)
    assert false == Enum.member?(1 ~> 0, 2)
    assert false == Enum.member?(1 ~> 0, 0)
  end

  test "Enum.slice/2" do
    assert [5, 6, 7, 8, 9, 10] = Enum.slice(0 ~> 100, 5..10)

    assert [5, 6, 7, 8, 9] = Enum.slice(0 ~> 10, 5..20)

    # last five elements (negative indexes)
    assert [25, 26, 27, 28, 29] = Enum.slice(0 ~> 30, -5..-1)

    # last five elements (mixed positive and negative indexes)
    assert [25, 26, 27, 28, 29] = Enum.slice(0 ~> 30, 25..-1)

    # out of bounds
    assert [] = Enum.slice(0 ~> 10, 10..20)

    # first is greater than last
    assert [] = Enum.slice(1 ~> 10, 6..5)
  end

  @tag :property
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
      assert expected_length == length(list)

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
