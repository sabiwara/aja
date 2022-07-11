defmodule KeyedQueue do
  @moduledoc """
  A variant of Queue where we directly use keys instead of a tuple within a key.
  This is just for benchmark purpose.

  `append/2` seems to be quite slower.

  ## Examples

      iex> import KeyedQueue, only: :macros
      iex> q(first ||| last) = queue = KeyedQueue.new(1..10)
      KeyedQueue.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
      iex> first
      1
      iex> last
      10
      iex> match?(x when queue_size(x) == 10, queue)
      true
      iex> KeyedQueue.new(1..5) |> KeyedQueue.append(:foo)
      KeyedQueue.new([1, 2, 3, 4, 5, :foo])

  """

  defstruct left: [], right: [], last: nil, size: 0

  defmacro q({:|||, _, [first, last]}) do
    case __CALLER__.context do
      :match ->
        quote do
          %KeyedQueue{right: [unquote(first) | _], last: unquote(last)}
        end

      _ ->
        raise ArgumentError, "The `q(first ||| last)` syntax can only be used in matches"
    end
  end

  defmacro queue_size(queue) do
    quote do
      :erlang.map_get(:size, unquote(queue))
    end
  end

  def size(queue), do: queue_size(queue)

  def new, do: %KeyedQueue{}

  def new(enumerable) do
    case Enum.count(enumerable) do
      0 ->
        %KeyedQueue{}

      1 ->
        value = Enum.at(enumerable, 0)
        %KeyedQueue{left: [], right: [value], last: value, size: 1}

      size ->
        {right, left} = Enum.split(enumerable, div(size + 1, 2))
        [last | _] = left = :lists.reverse(left)

        %KeyedQueue{left: left, right: right, last: last, size: size}
    end
  end

  def first(queue, default \\ nil)
  def first(%KeyedQueue{right: [first | _]}, _default), do: first
  def first(%KeyedQueue{}, default), do: default

  def last(queue, default \\ nil)
  def last(%KeyedQueue{size: 0}, default), do: default
  def last(%KeyedQueue{last: last}, _default), do: last

  def to_list(%KeyedQueue{left: left, right: right}) do
    right ++ :lists.reverse(left)
  end

  # need this clause to keep the invariant
  def append(%KeyedQueue{size: 0}, value) do
    %KeyedQueue{size: 1, left: [], right: [value], last: value}
  end

  def append(%KeyedQueue{size: size, left: left, right: right, last: _}, value) do
    %KeyedQueue{size: size + 1, left: [value | left], right: right, last: value}
  end

  def prepend(%KeyedQueue{size: 0}, value) do
    %KeyedQueue{size: 1, left: [], right: [value], last: value}
  end

  def prepend(%KeyedQueue{size: size, left: left, right: right, last: last}, value) do
    %KeyedQueue{size: size + 1, left: left, right: [value | right], last: last}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["KeyedQueue.new(", Inspect.List.inspect(KeyedQueue.to_list(queue), opts), ")"])
    end
  end
end
