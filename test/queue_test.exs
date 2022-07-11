defmodule QueueTest do
  use ExUnit.Case, async: true
  doctest Queue

  # for module <- [Queue, PeekableQueue, KeyedQueue, SimpleQueue] do
  for module <- [Queue, SimpleQueue] do
    @module module

    describe inspect(module) do
      test "empty queue" do
        queue = @module.new()
        assert @module.to_list(queue) == []
        assert @module.first(queue) == nil
        assert @module.last(queue) == nil
      end

      test "append to empty queue" do
        queue = @module.new() |> @module.append(:foo)
        assert @module.to_list(queue) == [:foo]
        assert @module.size(queue) == 1
        assert @module.first(queue) == :foo
        assert @module.last(queue) == :foo
      end

      test "prepend to empty queue" do
        queue = @module.new() |> @module.prepend(:foo)
        assert @module.to_list(queue) == [:foo]
        assert @module.size(queue) == 1
        assert @module.first(queue) == :foo
        assert @module.last(queue) == :foo
      end

      test "delete_* to empty queue" do
        assert @module.new() |> @module.delete_first() == @module.new()
        assert @module.new() |> @module.delete_last() == @module.new()
      end

      test "non-empty queue" do
        queue = @module.new(1..5)
        assert @module.to_list(queue) == [1, 2, 3, 4, 5]
        assert @module.size(queue) == 5
        assert @module.first(queue) == 1
        assert @module.last(queue) == 5
      end

      test "append to non-empty queue" do
        queue = @module.new(1..5) |> @module.append(:foo)
        assert @module.to_list(queue) == [1, 2, 3, 4, 5, :foo]
        assert @module.size(queue) == 6
        assert @module.first(queue) == 1
        assert @module.last(queue) == :foo
      end

      test "prepend to non-empty queue" do
        queue = @module.new(1..5) |> @module.prepend(:foo)
        assert @module.to_list(queue) == [:foo, 1, 2, 3, 4, 5]
        assert @module.size(queue) == 6
        assert @module.first(queue) == :foo
        assert @module.last(queue) == 5
      end

      test "delete_first to non-empty queue" do
        queue = @module.new(1..5) |> @module.delete_first()
        assert @module.to_list(queue) == [2, 3, 4, 5]
        assert @module.size(queue) == 4
        assert @module.first(queue) == 2
        assert @module.last(queue) == 5
      end

      test "delete_last to non-empty queue" do
        queue = @module.new(1..5) |> @module.delete_last()
        assert @module.to_list(queue) == [1, 2, 3, 4]
        assert @module.size(queue) == 4
        assert @module.first(queue) == 1
        assert @module.last(queue) == 4
      end

      test "delete_* on 1-sized queue" do
        assert @module.new([:foo]) |> @module.delete_first() == @module.new()
        assert @module.new([:foo]) |> @module.delete_first() == @module.new()

        assert @module.new() |> @module.append(:foo) |> @module.delete_first() == @module.new()
        assert @module.new() |> @module.append(:foo) |> @module.delete_last() == @module.new()

        assert @module.new() |> @module.prepend(:foo) |> @module.delete_first() == @module.new()
        assert @module.new() |> @module.prepend(:foo) |> @module.delete_last() == @module.new()
      end

      test "repeating delete_first" do
        max = 100

        Enum.reduce(1..max, @module.new(1..max), fn i, queue ->
          queue = @module.delete_first(queue)

          assert @module.to_list(queue) == Enum.to_list((1 + i)..max//1)
          assert @module.size(queue) == max - i

          if @module.size(queue) > 0 do
            assert @module.first(queue) == 1 + i
            assert @module.last(queue) == max
          else
            assert @module.first(queue) == nil
            assert @module.last(queue) == nil
          end

          queue
        end)
      end

      test "repeating delete_last" do
        max = 100

        Enum.reduce(1..max, @module.new(1..max), fn i, queue ->
          queue = @module.delete_last(queue)

          assert @module.to_list(queue) == Enum.to_list(1..(max - i)//1)
          assert @module.size(queue) == max - i

          if @module.size(queue) > 0 do
            assert @module.first(queue) == 1
            assert @module.last(queue) == max - i
          else
            assert @module.first(queue) == nil
            assert @module.last(queue) == nil
          end

          queue
        end)
      end
    end
  end
end
