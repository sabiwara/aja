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

  test "sigil_i" do
    "a" = ~i"a"
    "ゴゴゴ" = ~i"ゴゴゴ"
    ["int: ", "99", ".\n"] = ~i"int: #{99}.\n"
    ["atom: ", "foo", ".\n"] = ~i"atom: #{:foo}.\n"
    ["string: ", "bar", ".\n"] = ~i"string: #{"bar"}.\n"
    ["charlist: ", 'baz', ".\n"] = ~i"charlist: #{'baz'}.\n"
    ["iolist: ", [["abc"], 'def' | "ghi"], ".\n"] = ~i"iolist: #{[["abc"], 'def' | "ghi"]}.\n"

    ["assignments: ", "3", ".\n"] =
      ~i"assignments: #{
        a = 1
        b = 2
        a + b
      }.\n"

    iodata = ~i"[#{for i <- 1..3, do: ~i({"name": "foo_#{i}"},)}]"

    assert [
             91,
             [
               ["{\"name\": \"foo_", "1", "\"},"],
               ["{\"name\": \"foo_", "2", "\"},"],
               ["{\"name\": \"foo_", "3", "\"},"]
             ],
             93
           ] = iodata

    assert ~s([{"name": "foo_1"},{"name": "foo_2"},{"name": "foo_3"},]) = to_string(iodata)
  end
end
