defmodule A.RBSet do
  @moduledoc ~S"""
  A Red-Black tree implementation of a set. It keeps elements sorted in ascending order.

  It works as a drop-in replacement for the built-in `MapSet`.
  Unlike `MapSet` which does not keep keys in any particular order,
  `A.RBSet` stores keys in ascending order.

  Erlang's `:gb_sets` offer similar functionalities and performance.
  However `A.RBSet`:
  - is a better Elixir citizen: pipe-friendliness, `Enum` / `Inspect` / `Collectable` protocols
  - is more convenient and safer to use: no unsafe functions like `:gb_sets.from_ordset/1`
  - keeps the tree balanced on deletion [unlike `:gb_sets`](`:gb_sets.balance/1`)
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  ## Examples

  `A.RBSet` offers the same API as `MapSet`:

      iex> rb_set = A.RBSet.new([6, 6, 7, 7, 4, 1, 2, 3, 1.0, 5])
      #A.RBSet<[1.0, 2, 3, 4, 5, 6, 7]>
      iex> A.RBSet.member?(rb_set, 2)
      true
      iex> A.RBSet.member?(rb_set, 8)
      false
      iex> A.RBSet.put(rb_set, 4.25)
      #A.RBSet<[1.0, 2, 3, 4, 4.25, 5, 6, 7]>
      iex> A.RBSet.delete(rb_set, 1)
      #A.RBSet<[2, 3, 4, 5, 6, 7]>
      iex> A.RBSet.union(rb_set, A.RBSet.new([0, 2, 4, 6, 8]))
      #A.RBSet<[0, 1.0, 2, 3, 4, 5, 6, 7, 8]>
      iex> A.RBSet.intersection(rb_set, A.RBSet.new([0, 2, 4, 6, 8]))
      #A.RBSet<[2, 4, 6]>
      iex> A.RBSet.difference(rb_set, A.RBSet.new([0, 2, 4, 6, 8]))
      #A.RBSet<[1.0, 3, 5, 7]>
      iex> Enum.to_list(rb_set)
      [1.0, 2, 3, 4, 5, 6, 7]
      iex> [0, 1, 1.1, 2.2, 3.3] |> Enum.into(rb_set)
      #A.RBSet<[0, 1, 1.1, 2, 2.2, 3, 3.3, 4, 5, 6, 7]>

  Like for `MapSet`s, elements in a set don't have to be of the same type:

      iex> A.RBSet.new([1, :two, {"three"}])
      #A.RBSet<[1, :two, {"three"}]>

  ## Tree-specific functions

  Due to its sorted nature, `A.RBSet` also offers some extra methods not present in `MapSet`, like:
  - `first/1` and `last/1` to efficiently retrieve the first (smallest) / last (largest) element
  - `pop_first/1` and `pop_last/1` to efficiently pop the first (smallest) / last (largest) element
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> rb_set = A.RBSet.new([8, 6, 0, 4, 2, 2, 2])
      iex> A.RBSet.last(rb_set)
      8
      iex> {0, updated} = A.RBSet.pop_first(rb_set)
      iex> updated
      #A.RBSet<[2, 4, 6, 8]>
      iex> A.RBSet.foldr(rb_set, [], fn value, acc -> [value + 1 | acc] end)
      [1, 3, 5, 7, 9]

  ## With `Jason`

      iex> A.RBSet.new([6, 6, 7, 7, 4, 1, 2, 3, 1.0, 5]) |> Jason.encode!()
      "[1.0,2,3,4,5,6,7]"

  It also preserves the element order.

  ## Limitations: equality

  Like `:gb_sets`, `A.RBSet` comparisons based on `==/2`, `===/2` or the pin operator `^` are **UNRELIABLE**.

  In Elixir, pattern-matching and equality for structs work based on their internal representation.
  While this is a pragmatic design choice that simplifies the language, it means that we cannot
  rededine how they work for custom data structures.

  Tree-based sets that are semantically equal (same elements in the same order) might be considered
  non-equal when comparing their internals, because there is not a unique way of representing one same set.

  `A.RBSet.equal?/2` should be used instead:

      iex> rb_set1 = A.RBSet.new([1, 2])
      #A.RBSet<[1, 2]>
      iex> rb_set2 = A.RBSet.new([2, 1])
      #A.RBSet<[1, 2]>
      iex> rb_set1 == rb_set2
      false
      iex> A.RBSet.equal?(rb_set1, rb_set2)
      true
      iex> match?(^rb_set1, rb_set2)
      false

  ## Pattern-matching and opaque type

  An `A.RBSet` is represented internally using the `%A.RBSet{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `A.RBSet`:

      iex> match?(%A.RBSet{}, A.RBSet.new())
      true

  Note, however, than `A.RBSet` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  Use the functions in this module to perform operations on `A.RBSet`s, or the `Enum` module.

  ## Note about numbers

  Unlike `MapSet`s, `A.RBSet`s only uses ordering for element comparisons,
  not strict comparisons. Integers and floats are indistiguinshable as elements.

      iex> MapSet.new([1, 2, 3]) |> MapSet.member?(2.0)
      false
      iex> A.RBSet.new([1, 2, 3]) |> A.RBSet.member?(2.0)
      true

  Erlang's `:gb_sets` module works the same.

  ## Memory overhead

  `A.RBSet` takes roughly 1.2x more memory than a `MapSet` depending on the type of data:

      iex> elements = Enum.map(1..100, fn i -> <<i>> end)
      iex> map_set_size = MapSet.new(elements) |> :erts_debug.size()
      684
      iex> rb_set_size = A.RBSet.new(elements) |> :erts_debug.size()
      810
      iex> elements |> Enum.sort() |> :gb_sets.from_ordset() |> :erts_debug.size()
      703
      iex> div(100 * rb_set_size, map_set_size)
      118

  """

  # TODO: inline what is relevant
  # WARNING: be careful with non-tail recursive functions looping on the full tree!
  @compile {:inline, size: 1, member?: 2, put: 2, delete: 2, equal?: 2, equal_loop: 2}

  @type value :: term

  @opaque t(value) :: %__MODULE__{root: A.RBTree.Set.tree(value), size: non_neg_integer}
  @type t :: t(term)

  defstruct root: A.RBTree.Set.empty(), size: 0

  @doc """
  Returns a new empty set.

  ## Examples

      iex> A.RBSet.new()
      #A.RBSet<[]>

  """
  @spec new :: t
  def new(), do: %__MODULE__{}

  @doc """
  Creates a set from an enumerable.

  ## Examples

      iex> A.RBSet.new([:b, :a, 3])
      #A.RBSet<[3, :a, :b]>
      iex> A.RBSet.new([3, 3, 3, 2, 2, 1])
      #A.RBSet<[1, 2, 3]>

  """
  @spec new(Enum.t()) :: t
  def new(enumerable)

  def new(%__MODULE__{} = rb_set), do: rb_set

  def new(enumerable) do
    {size, root} = A.RBTree.Set.empty() |> A.RBTree.Set.insert_many(enumerable)

    %__MODULE__{root: root, size: size}
  end

  @doc """
  Creates a set from an enumerable via the transformation function.

  ## Examples

      iex> A.RBSet.new([1, 2, 1], fn x -> 2 * x end)
      #A.RBSet<[2, 4]>

  """
  @spec new(Enum.t(), (term -> val)) :: t(val) when val: value
  def new(enumerable, transform) when is_function(transform, 1) do
    enumerable
    |> Enum.map(transform)
    |> new()
  end

  @doc """
  Deletes `value` from `rb_set`.

  Returns a new set which is a copy of `rb_set` but without `value`.

  ## Examples

      iex> rb_set = A.RBSet.new([1, 2, 3])
      iex> A.RBSet.delete(rb_set, 4)
      #A.RBSet<[1, 2, 3]>
      iex> A.RBSet.delete(rb_set, 2)
      #A.RBSet<[1, 3]>

  """
  @spec delete(t(val1), val2) :: t(val1) when val1: value, val2: value
  def delete(%__MODULE__{root: root, size: size} = rb_set, value) do
    case A.RBTree.Set.delete(root, value) do
      :error ->
        rb_set

      new_root ->
        %__MODULE__{root: new_root, size: size - 1}
    end
  end

  @doc """
  Returns a set that is `rb_set1` without the members of `rb_set2`.

  ## Examples

      iex> A.RBSet.difference(A.RBSet.new([1, 2]), A.RBSet.new([2, 3, 4]))
      #A.RBSet<[1]>

  """
  @spec difference(t(val), t(val)) :: t(val) when val: value
  def difference(rb_set1, rb_set2)

  def difference(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    A.RBTree.Set.foldl(rb_set2.root, rb_set1, fn elem, acc -> delete(acc, elem) end)
  end

  # TODO same optimization as MapSet:
  # If the first set is less than twice the size of the second map, it is fastest
  # to re-accumulate elements in the first set that are not present in the second set.
  # def difference(%__MODULE__{}, %__MODULE__{}) do
  # end

  @doc """
  Checks if `rb_set1` and `rb_set2` have no members in common.

  ## Examples

      iex> A.RBSet.disjoint?(A.RBSet.new([1, 2]), A.RBSet.new([3, 4]))
      true
      iex> A.RBSet.disjoint?(A.RBSet.new([1, 2]), A.RBSet.new([2, 3]))
      false

  """
  @spec disjoint?(t, t) :: boolean
  def disjoint?(%__MODULE__{size: size1} = rb_set1, %__MODULE__{size: size2} = rb_set2)
      when size1 < size2 do
    disjoint?(rb_set2, rb_set1)
  end

  def disjoint?(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    not Enum.any?(rb_set2, fn elem -> member?(rb_set1, elem) end)
  end

  @doc """
  Checks if two sets are equal.

  The comparison between elements is done using `==/2`, not strict equality `===/2`.

  ## Examples

      iex> A.RBSet.equal?(A.RBSet.new([1, 2]), A.RBSet.new([2, 1, 1]))
      true
      iex> A.RBSet.equal?(A.RBSet.new([1.0, 2.0]), A.RBSet.new([2, 1, 1]))
      true
      iex> A.RBSet.equal?(A.RBSet.new([1, 2]), A.RBSet.new([3, 4]))
      false

  """
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

  @doc """
  Returns a set containing only members that `rb_set1` and `rb_set2` have in common.

  ## Examples

      iex> A.RBSet.intersection(A.RBSet.new([2, 1]), A.RBSet.new([3, 2, 4]))
      #A.RBSet<[2]>

      iex> A.RBSet.intersection(A.RBSet.new([2, 1]), A.RBSet.new([3, 4]))
      #A.RBSet<[]>

  """
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

  @doc """
  Checks if `rb_set` contains `value`.

  ## Examples

      iex> A.RBSet.member?(A.RBSet.new([1, 2, 3]), 2)
      true
      iex> A.RBSet.member?(A.RBSet.new([1, 2, 3]), 4)
      false

  """
  @spec member?(t, value) :: boolean
  def member?(rb_set, value)

  def member?(%__MODULE__{root: root}, value) do
    A.RBTree.Set.member?(root, value)
  end

  @doc """
  Inserts `value` into `rb_set` if `rb_set` doesn't already contain it.

  ## Examples

      iex> A.RBSet.put(A.RBSet.new([1, 2, 3]), 3)
      #A.RBSet<[1, 2, 3]>
      iex> A.RBSet.put(A.RBSet.new([1, 2, 3]), 4)
      #A.RBSet<[1, 2, 3, 4]>

  """
  @spec put(t(val), new_val) :: t(val | new_val) when val: value, new_val: value
  def put(rb_set, value)

  def put(%__MODULE__{root: root, size: size}, value) do
    case A.RBTree.Set.insert(root, value) do
      {:new, new_root} -> %__MODULE__{root: new_root, size: size + 1}
      {:overwrite, new_root} -> %__MODULE__{root: new_root, size: size}
    end
  end

  @doc """
  Returns the number of elements in `rb_set`.

  ## Examples

      iex> A.RBSet.size(A.RBSet.new([1, 2, 3]))
      3
      iex> A.RBSet.size(A.RBSet.new([1, 1, 1.0]))
      1

  """
  @spec size(t) :: non_neg_integer
  def size(rb_set)
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Checks if `rb_set1`'s members are all contained in `rb_set2`.

  This function checks if `rb_set1` is a subset of `rb_set2`.

  ## Examples

      iex> A.RBSet.subset?(A.RBSet.new([1, 2]), A.RBSet.new([1, 2, 3]))
      true
      iex> A.RBSet.subset?(A.RBSet.new([1, 2, 3]), A.RBSet.new([1, 2]))
      false

  """
  @spec subset?(t, t) :: boolean
  def subset?(%__MODULE__{} = rb_set1, %__MODULE__{} = rb_set2) do
    rb_set1.size <= rb_set2.size and Enum.all?(rb_set1, fn elem -> member?(rb_set2, elem) end)
  end

  @doc """
  Converts `rb_set` to a list.

  ## Examples

      iex> A.RBSet.to_list(A.RBSet.new([1, 2, 3]))
      [1, 2, 3]

  """
  @spec to_list(t(val)) :: [val] when val: value
  def to_list(rb_set)

  def to_list(%__MODULE__{root: root}) do
    A.RBTree.Set.to_list(root)
  end

  @doc """
  Returns a set containing all members of `rb_set1` and `rb_set2`.

  ## Examples

      iex> A.RBSet.union(A.RBSet.new([2, 1]), A.RBSet.new([4, 2, 3]))
      #A.RBSet<[1, 2, 3, 4]>

  """
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

  @doc """
  Finds the smallest element in the set. Returns `nil` for empty sets.

  This is very efficient and can be done in O(log(n)).
  It should be preferred over `Enum.min/3`.

  ## Examples

      iex> A.RBSet.new([4, 2, 3]) |> A.RBSet.first()
      2
      iex> A.RBSet.new() |> A.RBSet.first()
      nil
      iex> A.RBSet.new() |> A.RBSet.first(0)
      0

  """
  @spec first(t(val), val | nil) :: val | nil when val: value
  def first(rb_set, default \\ nil)

  def first(%__MODULE__{root: root}, default) do
    case A.RBTree.Set.min(root) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc """
  Finds the largest element in the set. Returns `nil` for empty sets.

  This is very efficient and can be done in O(log(n)).
  It should be preferred over `Enum.max/3`.

  ## Examples

      iex> A.RBSet.new([4, 2, 3]) |> A.RBSet.last()
      4
      iex> A.RBSet.new() |> A.RBSet.last()
      nil
      iex> A.RBSet.new() |> A.RBSet.last(0)
      0

  """
  @spec last(t(val), val | nil) :: val | nil when val: value
  def last(rb_set, default \\ nil)

  def last(%__MODULE__{root: root}, default) do
    case A.RBTree.Set.max(root) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc """
  Removes and returns the smallest element in the set.

  Returns a `{value, new_rb_set}` tuple when non-empty, or `nil` for empty sets.

  ## Examples

      iex> rb_set = A.RBSet.new([4, 2, 5, 3])
      iex> {2, updated} = A.RBSet.pop_first(rb_set)
      iex> updated
      #A.RBSet<[3, 4, 5]>
      iex> A.RBSet.new() |> A.RBSet.pop_first()
      nil

  """
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

  @doc """
  Removes and returns the largest element in the set.

  Returns a `{value, new_rb_set}` tuple when non-empty, or `nil` for empty sets.

  ## Examples

      iex> rb_set = A.RBSet.new([4, 2, 5, 3])
      iex> {5, updated} = A.RBSet.pop_last(rb_set)
      iex> updated
      #A.RBSet<[2, 3, 4]>
      iex> A.RBSet.new() |> A.RBSet.pop_last()
      nil

  """
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

  @doc """
  Folds (reduces) the given `rb_set` from the left with the function `fun`.
  Requires an accumulator `acc`.

  ## Examples

      iex> A.RBSet.new([22, 11, 33]) |> A.RBSet.foldl(0, &+/2)
      66
      iex> A.RBSet.new([22, 11, 33]) |> A.RBSet.foldl([], &([2 * &1 | &2]))
      [66, 44, 22]

  """
  def foldl(%__MODULE__{} = rb_set, acc, fun) when is_function(fun, 2) do
    A.RBTree.Set.foldl(rb_set.root, acc, fun)
  end

  @doc """
  Folds (reduces) the given `rb_set` from the right with the function `fun`.
  Requires an accumulator `acc`.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> A.RBSet.new([22, 11, 33]) |> A.RBSet.foldr(0, &+/2)
      66
      iex> A.RBSet.new([22, 11, 33]) |> A.RBSet.foldr([], &([2 * &1 | &2]))
      [22, 44, 66]

  """
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
