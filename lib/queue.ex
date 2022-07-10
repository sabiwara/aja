defmodule Queue do
  @moduledoc """
  An advanced queue which allows:
  - constant time access of the size, first and last element
  - pattern-matching on first and last element
  - size can be used in pattern-matching

  To achieve this, we keep track of the size as well as the
  last element, and the first element is always the head of
  the right list.

  ## Examples

      iex> import Queue, only: :macros
      iex> q(first ||| last) = queue = Queue.new(1..10)
      Queue.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
      iex> first
      1
      iex> last
      10
      iex> match?(x when queue_size(x) == 10, queue)
      true

  """

  @enforce_keys [:__internal__]
  defstruct @enforce_keys

  defmacrop wrapped(internal) do
    quote do
      %Queue{__internal__: unquote(internal)}
    end
  end

  defmacro q({:|||, _, [first, last]}) do
    case __CALLER__.context do
      :match ->
        quote do
          %Queue{__internal__: {_, _, [unquote(first) | _], unquote(last)}}
        end

      _ ->
        raise ArgumentError, "The `q(first ||| last)` syntax can only be used in matches"
    end
  end

  defmacro queue_size(queue) do
    quote do
      :erlang.element(1, :erlang.map_get(:__internal__, unquote(queue)))
    end
  end

  def new, do: wrapped({0})

  def new(enumerable) do
    case Enum.count(enumerable) do
      0 ->
        wrapped({0})

      1 ->
        value = Enum.at(enumerable, 0)
        wrapped({1, [], [value], value})

      size ->
        {right, left} = Enum.split(enumerable, div(size, 2))
        left = :lists.reverse(left)

        wrapped({size, left, right, hd(left)})
    end
  end

  def first(queue, default \\ nil)
  def first(wrapped({_}), default), do: default
  def first(wrapped({[first | _], _, _, _}), _default), do: first

  def last(queue, default \\ nil)
  def last(wrapped({_}), default), do: default
  def last(wrapped({_, _, _, last}), _default), do: last

  def to_list(wrapped({_})), do: []

  def to_list(wrapped({_, left, right, _})) do
    right ++ :lists.reverse(left)
  end

  def append(wrapped({_}), value), do: wrapped({1, [], [value], value})

  def append(queue = wrapped({size, left, right, _last}), value),
    # benchmarks tend to favor this style for append
    do: %{queue | __internal__: {size + 1, [value | left], right, value}}

  def prepend(wrapped({_}), value), do: wrapped({1, [], [value], value})

  def prepend(queue = wrapped({size, left, right, last}), value),
    do: %{queue | __internal__: {size + 1, left, [value | right], last}}

  def delete_first(wrapped(tuple)) when :erlang.element(1, tuple) <= 1, do: wrapped({0})

  def delete_first(wrapped({size, left, [_first | tail], last})) do
    size = size - 1

    case tail do
      [] ->
        {right, left} = left |> :lists.reverse() |> Enum.split(div(size, 2))
        left = :lists.reverse(left)
        wrapped({size, left, right, last})

      right ->
        wrapped({size, left, right, last})
    end
  end

  def delete_last(wrapped(tuple)) when :erlang.element(1, tuple) <= 1, do: wrapped({0})

  def delete_last(wrapped({2, _, [first | _], _last})), do: wrapped({1, [], [first], first})

  def delete_last(wrapped({size, [_ | tail], right, _last})) do
    size = size - 1

    case tail do
      [] ->
        {right, left} = right |> Enum.split(div(size, 2))
        left = [last | _] = :lists.reverse(left)
        wrapped({size, left, right, last})

      left = [last | _] ->
        wrapped({size, left, right, last})
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["Queue.new(", Inspect.List.inspect(Queue.to_list(queue), opts), ")"])
    end
  end
end
