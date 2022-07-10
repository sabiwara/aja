defmodule PeekableQueue do
  @moduledoc """
  An alternative implementation for benchmarking.
  It doesn't use a tuple but 2 keys directly in the struct.

  Since the first element is always the head of
  the right list, we can pattern-match on it.
  Doesn't support pattern-matching on the size or last element.
  """

  @enforce_keys [:left, :right]
  defstruct @enforce_keys

  defmacrop wrapped(left, right) do
    quote do
      %PeekableQueue{left: unquote(left), right: unquote(right)}
    end
  end

  defmacro q(first, {:..., _, _}) do
    case __CALLER__.context do
      :match ->
        quote do
          %PeekableQueue{right: [unquote(first) | _]}
        end

      _ ->
        raise ArgumentError, "The `q(first ||| last)` syntax can only be used in matches"
    end
  end

  def size(wrapped(left, right)) do
    length(left) + length(right)
  end

  def new, do: wrapped([], [])

  def new(enumerable) do
    case Enum.count(enumerable) do
      0 ->
        wrapped([], [])

      size ->
        {right, left} = Enum.split(enumerable, div(size, 2))
        left = :lists.reverse(left)

        wrapped(left, right)
    end
  end

  def first(queue, default \\ nil)
  def first(wrapped(_, [first, _]), _default), do: first
  def first(wrapped(_, []), default), do: default

  def last(queue, default \\ nil)
  def last(wrapped([last | _], _), _default), do: last
  def last(wrapped([], []), default), do: default
  def last(wrapped([], right), _default), do: List.last(right)

  def to_list(wrapped(left, right)) do
    right ++ :lists.reverse(left)
  end

  # need this clause to keep the invariant
  def append(wrapped([], []), value), do: wrapped([], [value])
  def append(wrapped(left, right), value), do: wrapped([value | left], right)

  def prepend(wrapped(left, right), value), do: wrapped(left, [value | right])

  def delete_first(wrapped(_left, [])), do: wrapped([], [])

  def delete_first(wrapped(left, [_first | tail])) do
    case tail do
      [] ->
        size = length(left)
        {right, left} = left |> :lists.reverse() |> Enum.split(div(size, 2))
        left = :lists.reverse(left)
        wrapped(left, right)

      right ->
        wrapped(left, right)
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}

      concat([
        "PeekableQueue.new(",
        Inspect.List.inspect(PeekableQueue.to_list(queue), opts),
        ")"
      ])
    end
  end
end
