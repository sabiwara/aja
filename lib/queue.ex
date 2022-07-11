defmodule Queue do
  @moduledoc """
  An advanced queue which allows:
  - constant time access of the size, first and last element
  - pattern-matching on first and last element
  - size can be used in pattern-matching

  To achieve this, we keep track of the size as well as the
  last element, and the first element is always the head of
  the left list.

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

  defstruct internal: {0, [], [], nil}

  defmacro q({:|||, _, [first, last]}) do
    case __CALLER__.context do
      :match ->
        quote do
          %Queue{internal: {_, [unquote(first) | _], _, unquote(last)}}
        end

      _ ->
        raise ArgumentError, "The `q(first ||| last)` syntax can only be used in matches"
    end
  end

  defmacro queue_size(queue) do
    quote do
      :erlang.element(1, :erlang.map_get(:internal, unquote(queue)))
    end
  end

  def size(queue), do: queue_size(queue)

  def new, do: %Queue{}

  def new(enumerable) do
    case Enum.count(enumerable) do
      0 ->
        %Queue{}

      1 ->
        value = Enum.at(enumerable, 0)
        %Queue{internal: {1, [value], [], value}}

      size ->
        {left, right} = Enum.split(enumerable, div(size + 1, 2))
        [last | _] = right = :lists.reverse(right)

        %Queue{internal: {size, left, right, last}}
    end
  end

  def first(queue, default \\ nil)
  def first(%Queue{internal: {_, [first | _], _, _}}, _default), do: first
  def first(%Queue{}, default), do: default

  def last(queue, default \\ nil)
  def last(%Queue{internal: {0, _, _, _}}, default), do: default
  def last(%Queue{internal: {_, _, _, last}}, _default), do: last

  def to_list(%Queue{internal: {_, left, right, _}}) do
    left ++ :lists.reverse(right)
  end

  def append(%Queue{internal: {0, _, _, _}}, value) do
    %Queue{internal: {1, [value], [], value}}
  end

  def append(queue = %Queue{internal: {size, left, right, _last}}, value) do
    # benchmarks seems to favor this style for append
    %{queue | internal: {size + 1, left, [value | right], value}}
  end

  def prepend(%Queue{internal: {0, _, _, _}}, value),
    do: %Queue{internal: {1, [value], [], value}}

  def prepend(queue = %Queue{internal: {size, left, right, last}}, value),
    do: %{queue | internal: {size + 1, [value | left], right, last}}

  def delete_first(%Queue{internal: {size, _, _, _}}) when size <= 1, do: %Queue{}

  def delete_first(%Queue{internal: {size, [_first | tail], right, last}}) do
    size = size - 1

    case tail do
      [] ->
        {right, left} = div(size, 2) |> :lists.split(right)
        left = :lists.reverse(left)
        %Queue{internal: {size, left, right, last}}

      left ->
        %Queue{internal: {size, left, right, last}}
    end
  end

  def delete_last(%Queue{internal: {size, _, _, _}}) when size <= 1, do: %Queue{}

  def delete_last(%Queue{internal: {2, [first | _], _, _last}}) do
    %Queue{internal: {1, [first], [], first}}
  end

  def delete_last(%Queue{internal: {size, left, [_ | tail], _last}}) do
    size = size - 1

    case tail do
      [] ->
        {left, right} = div(size + 1, 2) |> :lists.split(left)
        [last | _] = right = :lists.reverse(right)
        %Queue{internal: {size, left, right, last}}

      right = [last | _] ->
        %Queue{internal: {size, left, right, last}}
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
