defmodule A.RBSet do
  @moduledoc false

  @type value :: term

  @opaque t(value) :: %__MODULE__{root: A.RBTree.Set.tree(value), size: non_neg_integer}
  @type t :: t(term)

  defstruct root: A.RBTree.Set.empty(), size: 0

  @deprecated "Module A.RBSet will be removed"
  @spec new :: t
  def new(), do: %__MODULE__{}

  @deprecated "Module A.RBSet will be removed"
  @spec new(Enum.t()) :: t
  def new(enumerable)

  def new(%__MODULE__{} = rb_set), do: rb_set

  def new(enumerable) do
    {size, root} = A.RBTree.Set.empty() |> A.RBTree.Set.insert_many(enumerable)

    %__MODULE__{root: root, size: size}
  end

  @spec new(Enum.t(), (term -> val)) :: t(val) when val: value
  def new(enumerable, transform) when is_function(transform, 1) do
    enumerable
    |> Enum.map(transform)
    |> new()
  end

  @spec delete(t(val1), val2) :: t(val1) when val1: value, val2: value
  def delete(%__MODULE__{root: root, size: size} = rb_set, value) do
    case A.RBTree.Set.delete(root, value) do
      :error ->
        rb_set

      new_root ->
        %__MODULE__{root: new_root, size: size - 1}
    end
  end

  @spec difference(t(val), t(val)) :: t(val) when val: value
  def difference(rb_set1, rb_set2)

  def difference(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    A.RBTree.Set.foldl(rb_set2.root, rb_set1, fn elem, acc -> delete(acc, elem) end)
  end

  @spec disjoint?(t, t) :: boolean
  def disjoint?(%__MODULE__{size: size1} = rb_set1, %__MODULE__{size: size2} = rb_set2)
      when size1 < size2 do
    disjoint?(rb_set2, rb_set1)
  end

  def disjoint?(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    not Enum.any?(rb_set2, fn elem -> member?(rb_set1, elem) end)
  end

  @spec equal?(t, t) :: boolean
  def equal?(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    rb_set1.size == rb_set2.size &&
      equal_loop(A.RBTree.Set.iterator(rb_set1.root), A.RBTree.Set.iterator(rb_set2.root))
  end

  defp equal_loop(iterator1, iterator2) do
    case {A.RBTree.Set.next(iterator1), A.RBTree.Set.next(iterator2)} do
      {nil, nil} ->
        true

      {{elem1, next_iter1}, {elem2, next_iter2}} when elem1 == elem2 ->
        equal_loop(next_iter1, next_iter2)

      _ ->
        false
    end
  end

  @spec intersection(t(val), t(val)) :: t(val) when val: value
  def intersection(%__MODULE__{size: size1} = rb_set1, %__MODULE__{size: size2} = rb_set2)
      when size1 < size2 do
    intersection(rb_set2, rb_set1)
  end

  def intersection(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    rb_set2
    |> Enum.filter(fn elem -> member?(rb_set1, elem) end)
    |> new()
  end

  @spec member?(t, value) :: boolean
  def member?(rb_set, value)

  def member?(%__MODULE__{root: root}, value) do
    A.RBTree.Set.member?(root, value)
  end

  @spec put(t(val), new_val) :: t(val | new_val) when val: value, new_val: value
  def put(rb_set, value)

  def put(%__MODULE__{root: root, size: size}, value) do
    case A.RBTree.Set.insert(root, value) do
      {:new, new_root} -> %__MODULE__{root: new_root, size: size + 1}
      {:overwrite, new_root} -> %__MODULE__{root: new_root, size: size}
    end
  end

  @spec size(t) :: non_neg_integer
  def size(rb_set)
  def size(%__MODULE__{size: size}), do: size

  @spec subset?(t, t) :: boolean
  def subset?(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    rb_set1.size <= rb_set2.size and Enum.all?(rb_set1, fn elem -> member?(rb_set2, elem) end)
  end

  @spec to_list(t(val)) :: [val] when val: value
  def to_list(rb_set)

  def to_list(%__MODULE__{root: root}) do
    A.RBTree.Set.to_list(root)
  end

  @spec union(t(val1), t(val2)) :: t(val1 | val2) when val1: value, val2: value
  def union(rb_set1, rb_set2)

  def union(%__MODULE__{size: size1} = rb_set1, %__MODULE__{size: size2} = rb_set2)
      when size1 < size2 do
    union(rb_set2, rb_set1)
  end

  def union(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    {size, root} =
      A.RBTree.Set.foldl(rb_set2.root, {rb_set1.size, rb_set1.root}, fn elem, {count, tree} ->
        {result, new_tree} = A.RBTree.Set.insert(tree, elem)

        case result do
          :new -> {count + 1, new_tree}
          _ -> {count, new_tree}
        end
      end)

    %__MODULE__{root: root, size: size}
  end

  # Extra tree methods

  @spec first(t(val), val | nil) :: val | nil when val: value
  def first(rb_set, default \\ nil)

  def first(%__MODULE__{root: root}, default) do
    case A.RBTree.Set.min(root) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @spec last(t(val), val | nil) :: val | nil when val: value
  def last(rb_set, default \\ nil)

  def last(%__MODULE__{root: root}, default) do
    case A.RBTree.Set.max(root) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @spec pop_first(t(val)) :: {val, t(val)} | nil when val: value
  def pop_first(rb_set)

  def pop_first(%__MODULE__{size: size, root: root}) do
    case A.RBTree.Set.pop_min(root) do
      {value, new_root} ->
        new_rb_set = %__MODULE__{root: new_root, size: size - 1}
        {value, new_rb_set}

      :error ->
        nil
    end
  end

  @spec pop_last(t(val)) :: {val, t(val)} | nil when val: value
  def pop_last(rb_set)

  def pop_last(%__MODULE__{size: size, root: root}) do
    case A.RBTree.Set.pop_max(root) do
      {value, new_root} ->
        new_rb_set = %__MODULE__{root: new_root, size: size - 1}
        {value, new_rb_set}

      :error ->
        nil
    end
  end

  def foldl(%__MODULE__{} = rb_set, acc, fun) when is_function(fun, 2) do
    A.RBTree.Set.foldl(rb_set.root, acc, fun)
  end

  def foldr(%__MODULE__{} = rb_set, acc, fun) when is_function(fun, 2) do
    A.RBTree.Set.foldr(rb_set.root, acc, fun)
  end

  # Not private, but only exposed for protocols

  @doc false
  def reduce(%__MODULE__{root: root}, acc, fun), do: A.RBTree.Set.reduce(root, acc, fun)

  defimpl Collectable do
    def into(set) do
      fun = fn
        set_acc, {:cont, value} ->
          A.RBSet.put(set_acc, value)

        set_acc, :done ->
          set_acc

        _set_acc, :halt ->
          :ok
      end

      {set, fun}
    end
  end

  defimpl Enumerable do
    def count(set) do
      {:ok, A.RBSet.size(set)}
    end

    def member?(set, val) do
      {:ok, A.RBSet.member?(set, val)}
    end

    def slice(set) do
      size = A.RBSet.size(set)
      {:ok, size, &Enumerable.List.slice(A.RBSet.to_list(set), &1, &2, size)}
    end

    defdelegate reduce(set, acc, fun), to: A.RBSet
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(set, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["#A.RBSet<", Inspect.List.inspect(A.RBSet.to_list(set), opts), ">"])
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(set, opts) do
        set |> A.RBSet.to_list() |> Jason.Encode.list(opts)
      end
    end
  end
end
