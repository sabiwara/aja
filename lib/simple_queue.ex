defmodule SimpleQueue do
  @doc """
  A simple wrapper of :queue in a struct, just for benchmarking purpose.

  It doesn't allow any pattern-matching.
  """

  @enforce_keys [:__internal__]
  defstruct @enforce_keys

  defmacrop wrapped(internal) do
    quote do
      %SimpleQueue{__internal__: unquote(internal)}
    end
  end

  def size(queue), do: :queue.len(queue.__internal__)

  def new, do: wrapped(:queue.new())

  def new(enumerable) do
    enumerable |> Enum.to_list() |> :queue.from_list() |> wrapped()
  end

  def first(queue, default \\ nil)
  def first(wrapped({[], []}), default), do: default
  def first(wrapped(queue), _default), do: :queue.head(queue)

  def last(queue, default \\ nil)
  def last(wrapped({[], []}), default), do: default
  def last(wrapped(queue), _default), do: :queue.daeh(queue)

  def to_list(wrapped(queue)) do
    :queue.to_list(queue)
  end

  def append(wrapped(queue), value), do: :queue.in(value, queue) |> wrapped()
  def prepend(wrapped(queue), value), do: :queue.cons(value, queue) |> wrapped()

  def delete_first(empty = wrapped({[], []})), do: empty
  def delete_first(wrapped(queue)), do: :queue.drop(queue) |> wrapped()

  def delete_last(empty = wrapped({[], []})), do: empty
  def delete_last(wrapped(queue)), do: :queue.drop_r(queue) |> wrapped()

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["SimpleQueue.new(", Inspect.List.inspect(SimpleQueue.to_list(queue), opts), ")"])
    end
  end
end
