defmodule A.ExRangeTest do
  use ExUnit.Case, async: true

  import A, only: [~>: 2]

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

  test "stream suspension" do
    assert [{1, 0}, {2, 1}, {3, 2}, {4, 3}] =
             1 ~> 100 |> Stream.zip(Stream.interval(1)) |> Enum.take(4)
  end

  test "Enum.count/1" do
    assert 0 = Enum.count(0 ~> 0)
    assert 100 = Enum.count(0 ~> 100)
    assert 100 = Enum.count(100 ~> 0)
    assert 6 = Enum.count(3 ~> 9)
    assert 6 = Enum.count(9 ~> 3)
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
    assert [95, 94, 93, 92, 91, 90] = Enum.slice(100 ~> 0, 5..10)

    assert [5, 6, 7, 8, 9] = Enum.slice(0 ~> 10, 5..20)
    assert [5, 4, 3, 2, 1] = Enum.slice(10 ~> 0, 5..20)

    # last five elements (negative indexes)
    assert [25, 26, 27, 28, 29] = Enum.slice(0 ~> 30, -5..-1)
    assert [5, 4, 3, 2, 1] = Enum.slice(30 ~> 0, -5..-1)

    # last five elements (mixed positive and negative indexes)
    assert [25, 26, 27, 28, 29] = Enum.slice(0 ~> 30, 25..-1)
    assert [5, 4, 3, 2, 1] = Enum.slice(30 ~> 0, 25..-1)

    # out of bounds
    assert [] = Enum.slice(0 ~> 10, 10..20)
    assert [] = Enum.slice(10 ~> 0, 10..20)

    # first is greater than last
    assert [] = Enum.slice(1 ~> 10, 6..5)
    assert [] = Enum.slice(10 ~> 1, 6..5)
  end
end
