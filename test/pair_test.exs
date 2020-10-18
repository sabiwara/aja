defmodule A.PairTest do
  use ExUnit.Case, async: true

  doctest A.Pair

  @ok :ok

  test "doesn't work with non atoms" do
    assert_raise FunctionClauseError, fn -> "abc" |> A.Pair.wrap("ok") end
  end

  test "works with variables" do
    ok = :ok
    {:ok, "abc"} = "abc" |> A.Pair.wrap(ok)
    "abc" = {:ok, "abc"} |> A.Pair.unwrap!(ok)
  end

  test "works with constants" do
    {:ok, "abc"} = "abc" |> A.Pair.wrap(@ok)
    "abc" = {:ok, "abc"} |> A.Pair.unwrap!(@ok)
  end
end
