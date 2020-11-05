defmodule ATest do
  use ExUnit.Case, async: true

  import A

  doctest A

  test "ord/1 - new OrdMap" do
    assert A.OrdMap.new() == ord(%{})

    assert A.OrdMap.new([
             {"一", 1},
             {"二", 2},
             {"三", 3}
           ]) == ord(%{"一" => 1, "二" => 2, "三" => 3})

    assert A.OrdMap.new(a: A.OrdMap.new()) == ord(%{a: ord(%{})})
    assert A.OrdMap.new(tuples: [{}, {1}, {2, 3, 4}]) == ord(%{tuples: [{}, {1}, {2, 3, 4}]})

    # multiline
    assert A.OrdMap.new([
             {"a", %{lower: 97, upper: 65}},
             {"b", %{lower: 98, upper: 66}},
             {"c", %{lower: 99, upper: 67}}
           ]) ==
             ord(%{
               "a" => %{lower: ?a, upper: ?A},
               "b" => %{lower: ?b, upper: ?B},
               "c" => %{lower: ?c, upper: ?C}
             })
  end

  test "ord/1 - pattern matching" do
    ordered = A.OrdMap.new(a: "A", b: "B")

    ord(%{}) = A.OrdMap.new()
    ord(%{}) = ordered
    ord(%{a: "A"}) = ordered

    assert true == match?(ord(%{b: _b, a: _a}), ordered)

    assert false == match?(ord(%{}), %{})
    assert false == match?(ord(%{c: _c}), ordered)
    assert false == match?(ord(%{a: "not A"}), ordered)
  end

  test "ord/1 - errors" do
    err =
      assert_raise ArgumentError,
                   fn -> Code.eval_quoted(quote do: ord(a: "A")) end

    assert "Incorrect use of `A.ord/1`:\n  ord([a: \"A\"])." <> _ = err.message

    err =
      assert_raise ArgumentError,
                   fn -> Code.eval_quoted(quote do: ord(%{a | b})) end

    assert "Incorrect use of `A.ord/1`:\n  ord(%{a | b})." <> _ = err.message

    err =
      assert_raise ArgumentError,
                   fn ->
                     Code.eval_quoted(
                       quote do
                         fn x when x in ord(%{}) -> x end
                       end
                     )
                   end

    assert "`A.ord/1` cannot be used in guards" = err.message
  end
end
