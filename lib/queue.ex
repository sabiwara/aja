defmodule Aja.Queue do
  @moduledoc ~S"""
  A queue data structure with constant-time size, protocol implementations
  and pattern-matching capabilities.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      #Aja.Queue<[1, 2, 3, 4, 5, 6]>
      iex> Aja.Queue.append(queue, :foo)
      #Aja.Queue<[1, 2, 3, 4, 5, 6, :foo]>
      iex> Aja.Queue.prepend(queue, :foo)
      #Aja.Queue<[:foo, 1, 2, 3, 4, 5, 6]>

  ## Pattern-matching

  The `Aja.queue/1` and `Aja.queue_size/1` macros allow to
  pattern-match on queues based on their first and last
  elements, as well as size:

      iex> import Aja
      iex> queue(first ||| last) = queue = Aja.Queue.new(1..6)
      Aja.Queue.new([1, 2, 3, 4, 5, 6])
      iex> first
      1
      iex> last
      6
      iex> queue([]) = Aja.Queue.new([])
      iex> match?(x when queue_size(x) == 6, queue)
      true

  This can be helpful for control flow:

      case my_queue do
        q when queue_size(q) > 50 -> ...
        queue({:ok, value} ||| _) -> ...
        queue([]) -> ...
      end

  ## Comparison with `:queue`

  `Aja.Queue`'s implementation is inspired by the [`:queue`](`:queue`) module,
  however it brings some extra features:
  - pattern-matching (see section above)
  - implementation of protocols: `Inspect`, `Enumerable`, `Collectable`

  It comes with some overhead compared to `:queue`, but this is mostly due
  to the use of a struct.

  """

  defmodule EmptyError do
    defexception []

    @impl true
    def exception(_) do
      %__MODULE__{}
    end

    @impl true
    def message(%__MODULE__{}) do
      "empty queue error"
    end
  end

  @opaque internal(value) :: {non_neg_integer(), list(value), list(value), value | nil}
  @type t(value) :: %__MODULE__{__queue__: internal(value)}
  @type value :: any()
  @type t :: t(value)

  defstruct __queue__: {0, [], [], nil}

  defmacrop q(size, left, right, last) do
    quote do
      %__MODULE__{
        __queue__: {
          unquote(size),
          unquote(left),
          unquote(right),
          unquote(last)
        }
      }
    end
  end

  @doc """
  Returns the number of elements in `queue`.

  Runs in constant time.

  ## Examples

      iex> Aja.Queue.new(1000..2000) |> Aja.Queue.size()
      1001
      iex> Aja.Queue.new() |> Aja.Queue.size()
      0

  """
  @spec size(t()) :: non_neg_integer
  def size(queue)
  def size(q(size, _, _, _)), do: size

  @doc """
  Returns an empty queue.

  ## Examples

      iex> Aja.Queue.new()
      #Aja.Queue<[]>

  """
  @spec new :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a queue from an `enumerable`.

  Runs in linear time.

  ## Examples

      iex> Aja.Queue.new(10..15)
      #Aja.Queue<[10, 11, 12, 13, 14, 15]>

  """
  @spec new(Enumerable.t()) :: t()
  def new(enumerable) do
    enumerable
    |> Aja.EnumHelper.to_list()
    |> from_list()
  end

  defp from_list([]), do: %__MODULE__{}
  defp from_list([value]), do: q(1, [value], [], value)

  defp from_list(list) do
    size = length(list)
    {left, [last | _] = right} = split_reverse(list, size + 1)
    q(size, left, right, last)
  end

  @doc """
  Returns the first element in the `queue` or `default` if `queue` is empty.

  Runs in actual constant time.

  ## Examples

      iex> Aja.Queue.new(1..1000) |> Aja.Queue.first()
      1
      iex> Aja.Queue.new() |> Aja.Queue.first()
      nil

  """
  @spec first(t(val), default) :: val | default when val: value, default: term
  def first(queue, default \\ nil)
  def first(q(_, [first | _], _, _), _default), do: first
  def first(%__MODULE__{}, default), do: default

  @doc """
  Returns the last element in the `queue` or `default` if `queue` is empty.

  Runs in actual constant time.

  ## Examples

      iex> Aja.Queue.new(1..1000) |> Aja.Queue.last()
      1000
      iex> Aja.Queue.new() |> Aja.Queue.last()
      nil

  """
  @spec last(t(val), default) :: val | default when val: value, default: term
  def last(queue, default \\ nil)
  def last(q(0, _, _, _), default), do: default
  def last(q(_, _, _, last), _default), do: last

  @doc """
  Converts the `queue` to a list.

  Runs in linear time.

  ## Examples

      iex> Aja.Queue.new(10..20) |> Aja.Queue.to_list()
      [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
      iex> Aja.Queue.new() |> Aja.Queue.to_list()
      []

  """
  @spec to_list(t(val)) :: list(val) when val: value
  def to_list(queue)

  def to_list(q(_, left, right, _)) do
    left ++ :lists.reverse(right)
  end

  @doc """
  Appends a `value` at the end of a `queue`.

  Runs in constant time.

  ## Examples

      iex> Aja.Queue.new() |> Aja.Queue.append(:foo)
      #Aja.Queue<[:foo]>
      iex> Aja.Queue.new(1..5) |> Aja.Queue.append(:foo)
      #Aja.Queue<[1, 2, 3, 4, 5, :foo]>

  """
  @spec append(t(val), val) :: t(val) when val: value
  def append(queue, value)

  def append(q(0, _, _, _), value) do
    q(1, [value], [], value)
  end

  def append(queue = q(size, left, right, _last), value) do
    # benchmarks seems to favor this style for append
    %{queue | __queue__: {size + 1, left, [value | right], value}}
  end

  @doc """
  Prepends a `value` at the beginning of a `queue`.

  Runs in constant time.

  ## Examples

      iex> Aja.Queue.new() |> Aja.Queue.prepend(:foo)
      #Aja.Queue<[:foo]>
      iex> Aja.Queue.new(1..5) |> Aja.Queue.prepend(:foo)
      #Aja.Queue<[:foo, 1, 2, 3, 4, 5]>

  """
  @spec prepend(t(val), val) :: t(val) when val: value
  def prepend(queue, value)

  def prepend(q(0, _, _, _), value),
    do: q(1, [value], [], value)

  def prepend(queue = q(size, left, right, last), value),
    do: %{queue | __queue__: {size + 1, [value | left], right, last}}

  @doc """
  Removes the first value from the `queue` and returns the updated queue.

  Leaves the `queue` untouched if empty.

  Runs in amortized constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> Aja.Queue.delete_first(queue)
      #Aja.Queue<[2, 3, 4, 5, 6]>
      iex> Aja.Queue.delete_first(Aja.Queue.new())
      #Aja.Queue<[]>

  """
  @spec delete_first(t(val)) :: t(val) when val: value
  def delete_first(queue)
  def delete_first(q(size, _, _, _)) when size <= 1, do: %__MODULE__{}

  def delete_first(q(size, [_first | tail], right, last)) do
    size = size - 1

    case tail do
      [] ->
        {right, left} = split_reverse(right, size)
        q(size, left, right, last)

      left ->
        q(size, left, right, last)
    end
  end

  @doc """
  Removes the first value from the `queue` and returns the updated queue.

  Raises an `Aja.Queue.EmptyError` if empty.

  Runs in amortized constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> Aja.Queue.delete_first!(queue)
      #Aja.Queue<[2, 3, 4, 5, 6]>
      iex> Aja.Queue.delete_first!(Aja.Queue.new())
      ** (Aja.Queue.EmptyError) empty queue error

  """
  @spec delete_first!(t(val)) :: t(val) when val: value
  def delete_first!(queue)

  def delete_first!(q(0, _, _, _)) do
    raise EmptyError
  end

  def delete_first!(queue), do: delete_first(queue)

  @doc """
  Removes the last value from the `queue` and returns the updated queue.

  Leaves the `queue` untouched if empty.

  Runs in amortized constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> Aja.Queue.delete_last(queue)
      #Aja.Queue<[1, 2, 3, 4, 5]>
      iex> Aja.Queue.delete_last(Aja.Queue.new())
      #Aja.Queue<[]>

  """
  @spec delete_last(t(val)) :: t(val) when val: value
  def delete_last(queue)
  def delete_last(q(size, _, _, _)) when size <= 1, do: %__MODULE__{}

  def delete_last(q(2, [first | _], _, _last)) do
    q(1, [first], [], first)
  end

  def delete_last(q(size, left, right, _last)) do
    new_size = size - 1

    case right do
      [_ | right = [last | _]] ->
        q(new_size, left, right, last)

      [_] ->
        {left, right = [last | _]} = split_reverse(left, size)
        q(new_size, left, right, last)

      [] ->
        {left, [_ | right = [last | _]]} = split_reverse(left, size)
        q(new_size, left, right, last)
    end
  end

  @doc """
  Removes the last value from the `queue` and returns the updated queue.

  Raises an `Aja.Queue.EmptyError` if empty.

  Runs in amortized constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> Aja.Queue.delete_last!(queue)
      #Aja.Queue<[1, 2, 3, 4, 5]>
      iex> Aja.Queue.delete_last!(Aja.Queue.new())
      ** (Aja.Queue.EmptyError) empty queue error

  """
  @spec delete_last!(t(val)) :: t(val) when val: value
  def delete_last!(queue)

  def delete_last!(q(0, _, _, _)) do
    raise EmptyError
  end

  def delete_last!(queue), do: delete_last(queue)

  @doc """
  Removes the first value from the `queue` and returns both the value and the updated queue.

  Leaves the `queue` untouched if empty.

  Runs in effective constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> {1, updated} = Aja.Queue.pop_first(queue); updated
      #Aja.Queue<[2, 3, 4, 5, 6]>
      iex> {nil, updated} = Aja.Queue.pop_first(Aja.Queue.new()); updated
      #Aja.Queue<[]>

  """
  @spec pop_first(t(val), default) :: {val | default, t(val)} when val: value, default: term
  def pop_first(queue, default \\ nil)

  def pop_first(q(0, _, _, _), default), do: {default, %__MODULE__{}}

  def pop_first(queue = q(_, [first | _], _, _), _default) do
    {first, delete_first(queue)}
  end

  @doc """
  Removes the first value from the `queue` and returns both the value and the updated queue.

  Raises an `Aja.Queue.EmptyError` if empty.

  Runs in effective constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> {1, updated} = Aja.Queue.pop_first!(queue); updated
      #Aja.Queue<[2, 3, 4, 5, 6]>
      iex> {nil, updated} = Aja.Queue.pop_first!(Aja.Queue.new()); updated
      ** (Aja.Queue.EmptyError) empty queue error

  """
  @spec pop_first!(t(val)) :: {val, t(val)} when val: value
  def pop_first!(queue)

  def pop_first!(q(0, _, _, _)) do
    raise EmptyError
  end

  def pop_first!(queue = q(_, [first | _], _, _)) do
    {first, delete_first(queue)}
  end

  @doc """
  Removes the last value from the `queue` and returns both the value and the updated queue.

  Leaves the `queue` untouched if empty.

  Runs in effective constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> {6, updated} = Aja.Queue.pop_last(queue); updated
      #Aja.Queue<[1, 2, 3, 4, 5]>
      iex> {nil, updated} = Aja.Queue.pop_last(Aja.Queue.new()); updated
      #Aja.Queue<[]>

  """
  @spec pop_last(t(val), default) :: {val | default, t(val)} when val: value, default: term
  def pop_last(queue, default \\ nil)

  def pop_last(q(0, _, _, _), default), do: {default, %__MODULE__{}}

  def pop_last(queue = q(_, _, _, last), _default) do
    {last, delete_last(queue)}
  end

  @doc """
  Removes the last value from the `queue` and returns both the value and the updated queue.

  Raises an `Aja.Queue.EmptyError` if empty.

  Runs in effective constant time.

  ## Examples

      iex> queue = Aja.Queue.new(1..6)
      iex> {6, updated} = Aja.Queue.pop_last!(queue); updated
      #Aja.Queue<[1, 2, 3, 4, 5]>
      iex> {nil, updated} = Aja.Queue.pop_last!(Aja.Queue.new()); updated
      ** (Aja.Queue.EmptyError) empty queue error

  """
  @spec pop_last!(t(val)) :: {val, t(val)} when val: value
  def pop_last!(queue)

  def pop_last!(q(0, _, _, _)) do
    raise EmptyError
  end

  def pop_last!(queue = q(_, _, _, last)) do
    {last, delete_last(queue)}
  end

  defp split_reverse(list, size) do
    {left, right} = div(size, 2) |> :lists.split(list)
    {left, :lists.reverse(right)}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["#Aja.Queue<", Inspect.List.inspect(Aja.Queue.to_list(queue), opts), ">"])
    end
  end
end
