defmodule A.RBSetTest do
  use ExUnit.Case, async: true

  doctest A.RBSet

  test "new/1 should accept an A.RBSet and leave it untouched" do
    rb_set = A.RBSet.new([4, 2, 5, 3, 1])
    assert ^rb_set = A.RBSet.new(rb_set)
  end
end
