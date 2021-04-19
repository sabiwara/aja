defmodule ATest do
  use ExUnit.Case, async: true

  import A
  import A.TestHelpers

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

    # dynamic key/values
    {k1, v1, k2, v2, k3, v3} = {:foo, 45, :bar, 98, :baz, 76}

    assert A.OrdMap.new([{:foo, 45}, {:bar, 98}, {:baz, 76}]) ==
             ord(%{k1 => v1, k2 => v2, k3 => v3})

    # computed key/values
    {f, pop_args} = spy_callback(&(&1 * 2))

    assert A.OrdMap.new([{0, 20}, {2, 40}, {4, 60}]) ==
             ord(%{f.(0) => f.(10), f.(1) => f.(20), f.(2) => f.(30)})

    assert [0, 10, 1, 20, 2, 30] = pop_args.()

    # fixed key / computed values

    assert A.OrdMap.new(foo: 200, bar: 400, baz: 600) ==
             ord(%{foo: f.(100), bar: f.(200), baz: f.(300)})

    assert [100, 200, 300] = pop_args.()
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

    # pin operator
    {key, value} = {:bar, 32}
    assert ord(%{^key => ^value}) = A.OrdMap.new(foo: 46, bar: 32)
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

  test "ord/1 - warnings - literal key & values" do
    expected = A.OrdMap.new(foo: "Baz", bar: "Bar")

    warning =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert {^expected, []} =
                 Code.eval_quoted(
                   quote do
                     ord(%{foo: "Foo", bar: "Bar", foo: "Baz"})
                   end
                 )
      end)

    assert warning =~ "warning"
    assert warning =~ "key :foo will be overridden in ord map"
  end

  test "ord/1 - warnings - literal key, computed values" do
    expected = A.OrdMap.new(foo: 6, bar: 4)

    warning =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert {^expected, _} =
                 Code.eval_quoted(
                   quote do
                     fun = &(&1 * 2)
                     ord(%{foo: fun.(1), bar: fun.(2), foo: fun.(3)})
                   end
                 )
      end)

    assert warning =~ "warning"
    assert warning =~ "key :foo will be overridden in ord map"
  end

  test "vec/1 creation" do
    assert A.Vector.new([]) ==
             vec([])

    assert A.Vector.new(1..5) == vec([1, 2, 3, 4, 5])

    assert A.Vector.new(1..5) == vec(1..5)
    assert A.Vector.new(-5..-1) == vec(-5..-1)
    # TODO uncomment when dropping support for Elixir < 1.12
    # assert A.Vector.new(-20..20//5) == vec(-20..20//5)

    {f, pop_args} = spy_callback(&(&1 * 2))
    assert A.Vector.new([2, 4, 6, 8]) == vec([f.(1), f.(2), f.(3), f.(4)])
    assert [1, 2, 3, 4] = pop_args.()

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

    assert A.Vector.new(1..50) == vec(1..50)
  end

  test "vec/1 pattern matching" do
    assert vec([]) = A.Vector.new([])

    assert vec([1, 2, value, 4, 5]) = A.Vector.new(1..5)
    assert 3 = value

    assert vec([vec([a, b]), vec([c, d])]) =
             A.Vector.new([A.Vector.new([1, 2]), A.Vector.new([3, 4])])

    assert {1, 2, 3, 4} == {a, b, c, d}

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

    assert vec(_) = A.Vector.new([])
    assert vec(_) = A.Vector.new([1, 2])
    assert vec(_) = A.Vector.new(1..100)

    assert vec(1 ||| 2) = A.Vector.new(1..2)
    assert vec(1 ||| 20) = A.Vector.new(1..20)
    assert vec(1 ||| 200) = A.Vector.new(1..200)
    assert vec(1 ||| 2000) = A.Vector.new(1..2000)
    refute match?(vec(_ ||| _), A.Vector.new())
  end

  test "vec(x ||| y) outside patterns" do
    quoted = quote do: vec(1 ||| 2)

    assert_raise ArgumentError, fn -> Code.eval_quoted(quoted) end
  end

  test "vec/1 - errors" do
    err =
      assert_raise ArgumentError,
                   fn -> Code.eval_quoted(quote do: vec(a..b)) end

    assert "Incorrect use of `A.vec/1`:\n  vec(a..b)." <> _ = err.message
  end

  test "vec_size/1 in guards" do
    lt? = &match?(v when vec_size(v) < 10, &1)
    gt? = &match?(v when vec_size(v) > 10, &1)

    assert lt?.(A.Vector.new(1..9))
    assert lt?.(A.Vector.new([]))
    refute lt?.(A.Vector.new(1..10))
    refute lt?.([])
    refute lt?.(%{})

    assert gt?.(A.Vector.new(1..11))
    assert gt?.(A.Vector.new(1..100))
    refute gt?.(A.Vector.new(1..10))
    refute gt?.([])
    refute gt?.(%{})
  end

  test "vec_size/1 outside guards" do
    assert 20 = A.Vector.new(1..20) |> vec_size()
    assert 1000 = A.Vector.new(1..1000) |> vec_size()

    assert_raise FunctionClauseError, fn -> 8 = %{__vector__: {8}} |> vec_size() end
  end

  test "sigil_i" do
    "a" = ~i"a"
    "ゴゴゴ" = ~i"ゴゴゴ"
    ["int: ", "99", ".\n"] = ~i"int: #{99}.\n"
    ["atom: ", "foo", ".\n"] = ~i"atom: #{:foo}.\n"
    ["string: ", "bar", ".\n"] = ~i"string: #{"bar"}.\n"
    ["charlist: ", 'baz', ".\n"] = ~i"charlist: #{'baz'}.\n"
    ["iolist: ", [["abc"], 'def' | "ghi"], ".\n"] = ~i"iolist: #{[["abc"], 'def' | "ghi"]}.\n"

    ["assignments: ", "3", ".\n"] = ~i"assignments: #{a = 1
    b = 2
    a + b}.\n"

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
