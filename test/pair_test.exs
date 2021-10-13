defmodule Aja.PairTest do
  use ExUnit.Case, async: true

  doctest Aja.Pair

  @ok :ok

  test "doesn't work with non atoms" do
    assert_raise FunctionClauseError, fn -> "abc" |> Aja.Pair.wrap("ok") end
  end

  test "works with variables" do
    ok = :ok
    {:ok, "abc"} = "abc" |> Aja.Pair.wrap(ok)
    "abc" = {:ok, "abc"} |> Aja.Pair.unwrap!(ok)
  end

  test "works with constants" do
    {:ok, "abc"} = "abc" |> Aja.Pair.wrap(@ok)
    "abc" = {:ok, "abc"} |> Aja.Pair.unwrap!(@ok)
  end
end
