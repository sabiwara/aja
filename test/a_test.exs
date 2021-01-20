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

  test "vec/1 creation" do
    assert A.Vector.new([]) ==
             vec([])

    assert A.Vector.new(1..5) ==
             vec([1, 2, 3, 4, 5])

    assert A.Vector.new(1..50) ==
             vec([
               1,
               2,
               3,
               4,
               5,
               6,
               7,
               8,
               9,
               10,
               11,
               12,
               13,
               14,
               15,
               16,
               17,
               18,
               19,
               20,
               21,
               22,
               23,
               24,
               25,
               26,
               27,
               28,
               29,
               30,
               31,
               32,
               33,
               34,
               35,
               36,
               37,
               38,
               39,
               40,
               41,
               42,
               43,
               44,
               45,
               46,
               47,
               48,
               49,
               50
             ])
  end

  test "vec/1 pattern matching" do
    assert vec([]) = A.Vector.new([])

    assert vec([1, 2, value, 4, 5]) = A.Vector.new(1..5)
    assert 3 = value

    assert vec([
             first,
             2,
             3,
             4,
             5,
             6,
             7,
             8,
             9,
             10,
             11,
             12,
             13,
             14,
             15,
             16,
             17,
             18,
             19,
             20,
             21,
             22,
             23,
             24,
             middle,
             26,
             27,
             28,
             29,
             30,
             31,
             32,
             33,
             34,
             35,
             36,
             37,
             38,
             39,
             40,
             41,
             42,
             43,
             44,
             45,
             46,
             47,
             48,
             49,
             last
           ]) = A.Vector.new(1..50)

    assert {1, 25, 50} = {first, middle, last}

    assert vec(_) = A.Vector.new(1..100)
  end

  test "vec_size/1 in guards" do
    lt? = &match?(v when vec_size(v) < 10, &1)
    gt? = &match?(v when vec_size(v) > 10, &1)

    assert lt?.(A.Vector.new(1..9))
    refute lt?.(A.Vector.new(1..10))
    refute lt?.([])
    refute lt?.(%{})

    assert gt?.(A.Vector.new(1..11))
    refute gt?.(A.Vector.new(1..10))
    refute gt?.([])
    refute gt?.(%{})
  end

  test "vec_size/1 outside guards" do
    assert 20 = A.Vector.new(1..20) |> vec_size()
    assert 1000 = A.Vector.new(1..1000) |> vec_size()

    assert_raise FunctionClauseError, fn -> 8 = %{internal: {8}} |> vec_size() end
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
