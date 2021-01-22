defmodule A.RBTree.Set do
  @moduledoc false

  # TODO: inline what is relevant
  # WARNING: be careful with non-tail recursive functions looping on the full tree!
  @compile {:inline, balance_left: 1, balance_right: 1, member?: 2, insert: 2, max: 1, min: 1}

  @type color :: :R | :B
  @type tree(elem) :: :E | {color, tree(elem), elem, tree(elem)}
  @type iterator(elem) :: [tree(elem)]
  @type element :: term
  @type tree :: tree(element)

  # Use macros rather than tuples to detect errors. No runtime overhead.

  defmacrop t(color, left, elem, right) do
    quote do
      {unquote(color), unquote(left), unquote(elem), unquote(right)}
    end
  end

  defmacrop r(left, elem, right) do
    quote do
      {:R, unquote(left), unquote(elem), unquote(right)}
    end
  end

  defmacrop b(left, elem, right) do
    quote do
      {:B, unquote(left), unquote(elem), unquote(right)}
    end
  end

  @spec empty :: tree
  def empty, do: :E

  @doc """
  Checks the presence of a value in a set.

  Like all `A.RBTree.Set` functions, uses `==/2` for comparison,
  not strict equality `===/2`.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2, 3])
      iex> A.RBTree.Set.member?(tree, 2)
      true
      iex> A.RBTree.Set.member?(tree, 4)
      false
      iex> A.RBTree.Set.member?(tree, 2.0)
      true

  """
  @spec member?(tree(el), el) :: boolean when el: element
  def member?(:E, _x), do: false

  def member?(t(_color, left, y, _right), x) when x < y,
    do: member?(left, x)

  def member?(t(_color, _left, y, right), x) when x > y,
    do: member?(right, x)

  def member?(t(_color, _left, _y, _right), _x), do: true

  @doc """
  Inserts the value in a set tree and returns the updated tree.

  Returns a `{:new, new_tree}` tuple when the value was newly inserted.
  Returns a `{:overwrite, new_tree}` tuple when a non-striclty
  equal value was already present.

  Because `1.0` and `1` compare as equal values, inserting `1.0` can
  overwrite `1` and `new_tree` is going to be different.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 3])
      iex> A.RBTree.Set.insert(tree, 2)
      {:new, {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}}
      iex> A.RBTree.Set.insert(tree, 3.0)
      {:overwrite, {:B, :E, 1, {:R, :E, 3.0, :E}}}

  """
  @spec insert(tree(el), el) :: {:new | :overwrite, tree(el)}
        when el: element
  def insert(root, elem) do
    {result, t(_color, left, x, right)} = do_insert(root, elem)
    new_root = b(left, x, right)

    {result, new_root}
  end

  defp do_insert(:E, x), do: {:new, r(:E, x, :E)}

  defp do_insert(t(color, left, y, right), x) when x < y do
    {kind, new_left} = do_insert(left, x)
    new_tree = balance_left(t(color, new_left, y, right))
    {kind, new_tree}
  end

  defp do_insert(t(color, left, y, right), x) when x > y do
    {kind, new_right} = do_insert(right, x)
    new_tree = balance_right(t(color, left, y, new_right))
    {kind, new_tree}
  end

  # note: in the case of numbers, the previous and new keys might be different (e.g. `1` and `1.0`)
  # we use the new one, meaning inserting `1.0` will overwrite `1`.
  defp do_insert({color, left, _y, right}, x),
    do: {:overwrite, t(color, left, x, right)}

  @doc """
  Initializes a set tree from an enumerable.

  ## Examples

      iex> A.RBTree.Set.new([3, 2, 1, 2, 3])
      {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}

  """
  @spec new(Enumerable.t()) :: tree
  def new(list) do
    Enum.reduce(list, empty(), fn elem, acc ->
      {_result, new_tree} = insert(acc, elem)
      new_tree
    end)
  end

  @doc """
  Adds many values to an existing set tree, and returns both the new tree and
  the number of newly inserted values.

  Returns a `{inserted, new_tree}` tuple when `inserted` is the number of newly inserted
  values. Overwriting existing values do not count. This is useful to keep track of size
  changes.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2])
      iex> A.RBTree.Set.insert_many(tree, [2, 2.0, 3, 3.0])
      {1, {:B, {:B, :E, 1, :E}, 2.0, {:B, :E, 3.0, :E}}}

  """
  @spec insert_many(tree(el), Enumerable.t()) :: {non_neg_integer, tree(el)}
        when el: element
  def insert_many(tree, enumerable) do
    Enum.reduce(enumerable, {0, tree}, fn elem, {inserted, acc_tree} ->
      {result, new_tree} = insert(acc_tree, elem)

      case result do
        :new -> {inserted + 1, new_tree}
        _ -> {inserted, new_tree}
      end
    end)
  end

  @doc """
  Finds and removes the given `value` if exists, and returns the new tree.

  Uses the deletion algorithm as described in
  [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf).

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2, 3, 4])
      iex> A.RBTree.Set.delete(tree, 3)
      {:B, {:B, :E, 1, :E}, 2, {:B, :E, 4, :E}}
      iex> :error = A.RBTree.Set.delete(tree, 0)
      :error

  """
  @spec delete(tree(el), el) :: tree(el) | :error when el: element
  defdelegate delete(tree, value), to: A.RBTree.Set.CurseDeletion

  @doc """
  Finds and removes the leftmost (smallest) element in a set tree.

  Returns both the element and the new tree.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2, 3, 4])
      iex> {1, new_tree} = A.RBTree.Set.pop_min(tree)
      iex> new_tree
      {:B, {:R, :E, 2, :E}, 3, {:R, :E, 4, :E}}
      iex> :error = A.RBTree.Set.pop_min(A.RBTree.Set.empty())
      :error

  """
  @spec pop_min(tree(el)) :: {el, tree(el)} | :error when el: element
  def pop_min(tree) do
    case min(tree) do
      :error ->
        :error

      {:ok, value} ->
        new_tree = delete(tree, value)
        {value, new_tree}
    end
  end

  @doc """
  Finds and removes the rightmost (largest) element in a set tree.

  Returns both the element and the new tree.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2, 3, 4])
      iex> {4, new_tree} = A.RBTree.Set.pop_max(tree)
      iex> new_tree
      {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}
      iex> :error = A.RBTree.Set.pop_max(A.RBTree.Set.empty())
      :error

  """
  @spec pop_max(tree(el)) :: {el, tree(el)} | :error when el: element
  def pop_max(tree) do
    case max(tree) do
      :error ->
        :error

      {:ok, value} ->
        new_tree = delete(tree, value)
        {value, new_tree}
    end
  end

  @doc """
  Returns the tree as a list.

  ## Examples

      iex> A.RBTree.Set.new([3, 2, 2.0, 3, 3.0, 1, 3]) |> A.RBTree.Set.to_list()
      [1, 2.0, 3]
      iex> A.RBTree.Set.new([b: "B", c: "C", a: "A"]) |> A.RBTree.Set.to_list()
      [{:a, "A"}, {:b, "B"}, {:c, "C"}]
      iex> A.RBTree.Set.empty() |> A.RBTree.Set.to_list()
      []

  """
  @spec to_list(tree(el)) :: [el] when el: element
  def to_list(root), do: to_list(root, [])

  # note: same as erlang gb_tree, not tail recursive. not sure it is beneficial?
  defp to_list(:E, acc), do: acc

  defp to_list(t(_color, left, x, right), acc) do
    to_list(left, [x | to_list(right, acc)])
  end

  @doc """
  Computes the "length" of the tree by looping and counting each node.

  ## Examples

      iex> tree = A.RBTree.Set.new([1, 2, 2.0, 3, 3.0, 3])
      iex> A.RBTree.Set.node_count(tree)
      3
      iex> A.RBTree.Set.node_count(A.RBTree.Set.empty())
      0

  """
  @spec node_count(tree(el)) :: non_neg_integer when el: element
  def node_count(root), do: node_count(root, 0)

  defp node_count(t(_color, left, _x, right), acc) do
    node_count(left, node_count(right, acc + 1))
  end

  defp node_count(:E, acc), do: acc

  @doc """
  Finds the leftmost (smallest) element of a tree

  ## Examples

      iex> A.RBTree.Set.new(["B", "D", "A", "C"]) |> A.RBTree.Set.max()
      {:ok, "D"}
      iex> A.RBTree.Set.new([]) |> A.RBTree.Set.max()
      :error

  """
  @spec max(tree(el)) :: {:ok, el} | :error when el: element
  def max(t(_, _left, x, :E)), do: {:ok, x}
  def max(t(_, _left, _x, right)), do: max(right)
  def max(:E), do: :error

  @doc """
  Finds the rightmost (largest) element of a tree

  ## Examples

      iex> A.RBTree.Set.new(["B", "D", "A", "C"]) |> A.RBTree.Set.min()
      {:ok, "A"}
      iex> A.RBTree.Set.new([]) |> A.RBTree.Set.min()
      :error

  """
  @spec min(tree(el)) :: {:ok, el} | :error when el: element
  def min(t(_, :E, x, _right)), do: {:ok, x}
  def min(t(_, left, _x, _right)), do: min(left)
  def min(:E), do: :error

  @doc """
  Returns an iterator looping on a tree from left-to-right.

  The resulting iterator should be looped over using `next/1`.

  ## Examples

      iex> iterator = A.RBTree.Set.new([22, 11]) |> A.RBTree.Set.iterator()
      iex> {i1, iterator} = A.RBTree.Set.next(iterator)
      iex> {i2, iterator} = A.RBTree.Set.next(iterator)
      iex> A.RBTree.Set.next(iterator)
      nil
      iex> [i1, i2]
      [11, 22]

  """
  @spec iterator(tree(el)) :: iterator(el) when el: element
  def iterator(root) do
    iterator(root, [])
  end

  defp iterator(t(_color, :E, _elem, _right) = tree, acc), do: [tree | acc]
  defp iterator(t(_color, left, _elem, _right) = tree, acc), do: iterator(left, [tree | acc])
  defp iterator(:E, acc), do: acc

  @doc """
  Walk a tree using an iterator yielded by `iterator/1`.

  ## Examples

      iex> iterator = A.RBTree.Set.new([22, 11]) |> A.RBTree.Set.iterator()
      iex> {i1, iterator} = A.RBTree.Set.next(iterator)
      iex> {i2, iterator} = A.RBTree.Set.next(iterator)
      iex> A.RBTree.Set.next(iterator)
      nil
      iex> [i1, i2]
      [11, 22]

  """
  @spec iterator(iterator(el)) :: {el, iterator(el)} | nil when el: element
  def next([t(_color, _left, elem, right) | acc]),
    do: {elem, iterator(right, acc)}

  def next([]), do: nil

  @doc """
  Folds (reduces) the given tree from the left with a function. Requires an accumulator.

  ## Examples

      iex> A.RBTree.Set.new([22, 11, 33]) |> A.RBTree.Set.foldl(0, &+/2)
      66
      iex> A.RBTree.Set.new([22, 11, 33]) |> A.RBTree.Set.foldl([], &([2 * &1 | &2]))
      [66, 44, 22]

  """
  def foldl(tree, acc, fun) when is_function(fun, 2) do
    do_foldl(tree, acc, fun)
  end

  defp do_foldl(t(_color, left, x, right), acc, fun) do
    fold_right = do_foldl(left, acc, fun)
    new_acc = fun.(x, fold_right)
    do_foldl(right, new_acc, fun)
  end

  defp do_foldl(:E, acc, _fun), do: acc

  @doc """
  Folds (reduces) the given tree from the right with a function. Requires an accumulator.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> A.RBTree.Set.new([22, 11, 33]) |> A.RBTree.Set.foldr(0, &+/2)
      66
      iex> A.RBTree.Set.new([22, 11, 33]) |> A.RBTree.Set.foldr([], &([2 * &1 | &2]))
      [22, 44, 66]

  """
  def foldr(tree, acc, fun) when is_function(fun, 2) do
    do_foldr(tree, acc, fun)
  end

  defp do_foldr(t(_color, left, x, right), acc, fun) do
    fold_right = do_foldr(right, acc, fun)
    new_acc = fun.(x, fold_right)
    do_foldr(left, new_acc, fun)
  end

  defp do_foldr(:E, acc, _fun), do: acc

  # TODO add right-to-left iterator?

  @doc """
  Helper to implement `Enumerable.reduce/3` in data structures using
  the underlying tree.
  """
  def reduce(tree, acc, fun) do
    iterator = iterator(tree)
    reduce_iterator(iterator, acc, fun)
  end

  defp reduce_iterator(_iterator, {:halt, acc}, _fun), do: {:halted, acc}

  defp reduce_iterator(iterator, {:suspend, acc}, fun),
    do: {:suspended, acc, &reduce_iterator(iterator, &1, fun)}

  defp reduce_iterator(iterator, {:cont, acc}, fun) do
    case next(iterator) do
      {elem, new_iterator} ->
        reduce_iterator(new_iterator, fun.(elem, acc), fun)

      nil ->
        {:done, acc}
    end
  end

  # Analysis functions

  def height(t(_color, left, _key_value, right)) do
    1 + max(height(left), height(right))
  end

  def height(:E), do: 0

  def black_height(b(left, _x, _right)), do: 1 + black_height(left)
  def black_height(r(left, _x, _right)), do: black_height(left)
  def black_height(:E), do: 0

  @doc """
  Checks the [red-black invariant](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree#Properties)
  is respected:

  > Each tree is either red or black.
    The root is black. This rule is sometimes omitted. Since the root can always be changed from red to black, but not necessarily vice versa, this rule has little effect on analysis.
    (All leaves (NIL) are black.)
    If a tree is red, then both its children are black.
    Every path from a given tree to any of its descendant NIL trees goes through the same number of black trees.

  Returns either an `{:ok, black_height}` tuple if respected and `black_height` is consistent,
  or an `{:error, reason}` tuple if violated.

  ## Examples

      iex> A.RBTree.Set.check_invariant(:E)
      {:ok, 0}
      iex> A.RBTree.Set.check_invariant({:B, :E, 1, :E})
      {:ok, 1}
      iex> A.RBTree.Set.check_invariant({:R, :E, 1, :E})
      {:error, "No red root allowed"}
      iex> A.RBTree.Set.check_invariant({:B, {:B, :E, 1, :E}, 2, :E})
      {:error, "Inconsistent black length"}
      iex> A.RBTree.Set.check_invariant({:B, {:R, {:R, :E, 1, :E}, 2, :E}, 3, :E})
      {:error, "Red tree has red child"}
  """
  @spec check_invariant(tree) :: {:ok, non_neg_integer} | {:error, String.t()}
  def check_invariant(root) do
    case root do
      r(_, _, _) -> {:error, "No red root allowed"}
      _ -> do_check_invariant(root)
    end
  end

  defp do_check_invariant(:E), do: {:ok, 0}

  defp do_check_invariant(r(r(_, _, _), _, _right)),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant(r(_left, _, r(_, _, _))),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant(t(color, left, _, right)) do
    with {:ok, hl} <- do_check_invariant(left),
         {:ok, hr} <- do_check_invariant(right) do
      case {hl, hr, color} do
        {h, h, :B} -> {:ok, h + 1}
        {h, h, :R} -> {:ok, h}
        _ -> {:error, "Inconsistent black length"}
      end
    end
  end

  # Private functions

  @spec balance_left(tree(el)) :: tree(el) when el: element
  defp balance_left(tree) do
    case tree do
      b(r(r(a, x, b), y, c), z, d) -> r(b(a, x, b), y, b(c, z, d))
      b(r(a, x, r(b, y, c)), z, d) -> r(b(a, x, b), y, b(c, z, d))
      balanced -> balanced
    end
  end

  @spec balance_right(tree(el)) :: tree(el) when el: element
  defp balance_right(tree) do
    case tree do
      b(a, x, r(r(b, y, c), z, d)) -> r(b(a, x, b), y, b(c, z, d))
      b(a, x, r(b, y, r(c, z, d))) -> r(b(a, x, b), y, b(c, z, d))
      balanced -> balanced
    end
  end
end
