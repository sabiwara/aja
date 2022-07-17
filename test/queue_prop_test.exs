defmodule Aja.Queue.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Aja
  import Aja.TestDataGenerators

  @moduletag timeout: :infinity
  @moduletag :property

  def value do
    frequency([
      {20, integer()},
      {4, simple_value()},
      {1, term()}
    ])
  end

  def operation do
    one_of([
      {:append, value()},
      {:prepend, value()},
      :delete_last,
      :delete_first
    ])
  end

  def apply_operation(%Aja.Queue{} = queue, {:append, value}) do
    new_queue = Aja.Queue.append(queue, value)

    assert Aja.Queue.size(new_queue) == Aja.Queue.size(queue) + 1
    assert Aja.Queue.last(new_queue) == value
    assert queue(_ ||| ^value) = new_queue

    new_queue
  end

  def apply_operation(%Aja.Queue{} = queue, {:prepend, value}) do
    new_queue = Aja.Queue.prepend(queue, value)

    assert Aja.Queue.size(new_queue) == Aja.Queue.size(queue) + 1
    assert Aja.Queue.first(new_queue) == value
    assert queue(^value ||| _) = new_queue

    new_queue
  end

  def apply_operation(%Aja.Queue{} = queue, :delete_first) do
    new_queue = Aja.Queue.delete_first(queue)
    assert Aja.Queue.pop_first(queue) == {Aja.Queue.first(queue), new_queue}

    if Aja.Queue.size(queue) > 1 do
      queue(_ ||| last) = queue
      assert queue(_ ||| ^last) = new_queue
      assert Aja.Queue.last(new_queue) == last
      assert Aja.Queue.size(new_queue) == Aja.Queue.size(queue) - 1
      assert Aja.Queue.delete_first!(queue) == new_queue
      assert Aja.Queue.pop_first!(queue) == {Aja.Queue.first(queue), new_queue}
    else
      assert new_queue == Aja.Queue.new()
    end

    new_queue
  end

  def apply_operation(%Aja.Queue{} = queue, :delete_last) do
    new_queue = Aja.Queue.delete_last(queue)
    assert Aja.Queue.pop_last(queue) == {Aja.Queue.last(queue), new_queue}

    if Aja.Queue.size(queue) > 1 do
      queue(first ||| _) = queue
      assert queue(^first ||| _) = new_queue
      assert Aja.Queue.first(new_queue) == first
      assert Aja.Queue.size(new_queue) == Aja.Queue.size(queue) - 1
      assert Aja.Queue.delete_last!(queue) == new_queue
      assert Aja.Queue.pop_last!(queue) == {Aja.Queue.last(queue), new_queue}
    else
      assert new_queue == Aja.Queue.new()
    end

    new_queue
  end

  def assert_properties(%Aja.Queue{} = queue) do
    as_list = Aja.Queue.to_list(queue)

    length_list = length(as_list)
    assert Aja.Queue.size(queue) == length_list
    # assert Enum.count(queue) == length_list
    # assert Aja.Enum.count(queue) == length_list
    assert queue_size(queue) == length_list
    assert match?(q when queue_size(q) == length_list, queue)

    first = Aja.Queue.first(queue)
    last = Aja.Queue.last(queue)

    assert first == List.first(as_list)
    assert last == List.last(as_list)

    if length_list > 0 do
      assert queue(^first ||| ^last) = queue
    end
  end

  property "any series of transformation should yield a valid ordered map" do
    check all(
            initial <- list_of(value()),
            operations <- list_of(operation())
          ) do
      initial_queue = Aja.Queue.new(initial)

      queue =
        Enum.reduce(operations, initial_queue, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(queue)
    end
  end
end
