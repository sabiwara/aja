defmodule A.RBTree.Map do
  @moduledoc ~S"""
  A low-level implementation of a Red-Black Tree Map, used under the hood in `A.RBMap` and `A.OrdMap`.

  Implementation following Chris Okasaki's "Purely Functional Data Structures",
  with the delete method as described in
  [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf)
  from German and Might.

  It should have equivalent performance as `:gb_trees` from the Erlang standard library (see benchmarks).

  ## Disclaimer

  This module is the low-level implementation behind other data structures, it is NOT meant to be used directly.

  If you want something ready to use, you should check `A.RBMap`.

  Probably the only case you might be interested in `A.RBTree.Map` itself is if you want to implement
  your own data structures on the top of it, or out of curiosity.

  ## Examples

      iex> A.RBTree.Map.new([])
      :E
      iex> map = A.RBTree.Map.new([b: "B", c: "C", a: "A"])
      {:B, {:R, :E, :a, "A", :E}, :b, "B", {:R, :E, :c, "C", :E}}
      iex> A.RBTree.Map.fetch(map, :c)
      {:ok, "C"}
      iex> {:new, _new_map} = A.RBTree.Map.insert(map, :bar, "BAR")
      {:new, {:B, {:B, {:R, :E, :a, "A", :E}, :b, "B", :E}, :bar, "BAR", {:B, :E, :c, "C", :E}}}
      iex> {"B", _new_map} = A.RBTree.Map.pop(map, :b)
      {"B", {:B, {:R, :E, :a, "A", :E}, :c, "C", :E}}
      iex> A.RBTree.Map.pop(map, :bar)
      :error
      iex> A.RBTree.Map.new([b: "B", x: "X", c: "C", a: "A"]) |> A.RBTree.Map.to_list()
      [a: "A", b: "B", c: "C", x: "X"]

  ## For the curious reader: more about deletion

  Insertion is easy enough in an immutable Red-Black Tree, deletion however is pretty tricky.
  Two implementations have been tried:
  1. [this approach](http://matt.might.net/articles/red-black-delete/) from Matt Might
  2. [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf) from Germane and Might

  `1.` The Haskell implementation used as a reference has a bug and seems not to be respecting the Red-Black invariant,
  as suggested [here](https://github.com/sweirich/dth/blob/master/examples/red-black/MightRedBlackGADT.hs).

  `2.` was retained and it was confirmed that the Red-Black invariant was maintained.

  Finally, a third approach from Kahr's
  ([example Haskell implementation](https://github.com/sweirich/dth/blob/master/examples/red-black/RedBlack.lhs#L227))
  seems to be faster and might be tried in future iterations.

  ## Note about numbers

  Unlike regular maps, `A.RBTree.Map`s only uses ordering for key comparisons,
  meaning integers and floats are indistiguinshable as keys.

      iex> %{1 => "一", 2 => "二"} |> Map.fetch(2)
      {:ok, "二"}
      iex> %{1 => "一", 2 => "二"} |> Map.fetch(2.0)
      :error
      iex> A.RBTree.Map.new(%{1 => "一", 2 => "二"}) |> A.RBTree.Map.fetch(2)
      {:ok, "二"}
      iex> A.RBTree.Map.new(%{1 => "一", 2 => "二"}) |> A.RBTree.Map.fetch(2.0)
      {:ok, "二"}

  Erlang's `:gb_trees` module works the same.
  """

  # TODO: inline what is relevant
  # WARNING: be careful with non-tail recursive functions looping on the full tree!
  @compile {:inline,
            balance_left: 1, balance_right: 1, fetch: 2, insert: 3, do_insert: 3, max: 1, min: 1}

  @type color :: :R | :B
  @type tree(key, value) :: :E | {color, tree(key, value), key, value, tree(key, value)}
  @type iterator(key, value) :: [tree(key, value)]
  @type key :: term
  @type value :: term
  @type tree :: tree(key, value)

  @spec empty :: tree
  def empty, do: :E

  # Use macros rather than tuples to detect errors. No runtime overhead.

  defmacrop t(color, left, key, value, right) do
    quote do
      {unquote(color), unquote(left), unquote(key), unquote(value), unquote(right)}
    end
  end

  defmacrop r(left, key, value, right) do
    quote do
      {:R, unquote(left), unquote(key), unquote(value), unquote(right)}
    end
  end

  defmacrop b(left, key, value, right) do
    quote do
      {:B, unquote(left), unquote(key), unquote(value), unquote(right)}
    end
  end

  @doc """
  Finds the value corresponding to the given `key` if exists.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{a: "A", b: "B", c: "C"})
      iex> A.RBTree.Map.fetch(tree, :b)
      {:ok, "B"}
      iex> A.RBTree.Map.fetch(tree, :d)
      :error

  """
  @spec fetch(tree(k, v), k) :: v when k: key, v: value
  def fetch(t(_color, left, xk, xv, right), key) do
    cond do
      key < xk -> fetch(left, key)
      key > xk -> fetch(right, key)
      true -> {:ok, xv}
    end
  end

  def fetch(:E, _key), do: :error

  @doc """
  Inserts the key-value pair in a map tree and returns the updated tree.

  Returns a `{:new, new_tree}` tuple when the key was newly created,
  a `{:overwrite, new_tree}` tuple when the key was already present.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{1 => "A", 3 => "C"})
      iex> A.RBTree.Map.insert(tree, 2, "B")
      {:new, {:B, {:B, :E, 1, "A", :E}, 2, "B", {:B, :E, 3, "C", :E}}}
      iex> A.RBTree.Map.insert(tree, 3, "C!!!")
      {:overwrite, {:B, :E, 1, "A", {:R, :E, 3, "C!!!", :E}}}

  """
  @spec insert(tree(k, v), k, v) :: {:new | :overwrite, tree(k, v)}
        when k: key, v: value
  def insert(root, key, value) do
    {result, t(_color, left, xk, xv, right)} = do_insert(root, key, value)
    new_root = b(left, xk, xv, right)

    {result, new_root}
  end

  defp do_insert(t(color, left, xk, xv, right), key, value)
       when key < xk do
    {kind, new_left} = do_insert(left, key, value)
    new_tree = balance_left(t(color, new_left, xk, xv, right))
    {kind, new_tree}
  end

  defp do_insert(t(color, left, xk, xv, right), key, value)
       when key > xk do
    {kind, new_right} = do_insert(right, key, value)
    new_tree = balance_right(t(color, left, xk, xv, new_right))
    {kind, new_tree}
  end

  # note: in the case of numbers, the previous and new keys might be different (e.g. `1` and `1.0`)
  # we use the new one, meaning inserting `1.0` will overwrite `1`.
  defp do_insert(t(color, left, _xk, _xv, right), key, value),
    do: {:overwrite, t(color, left, key, value, right)}

  defp do_insert(:E, key, value), do: {:new, r(:E, key, value, :E)}

  @doc """
  Initializes a map tree from an enumerable.

  ## Examples

      iex> A.RBTree.Map.new(%{1 => "A", 2 => "B", 3 => "C"})
      {:B, {:B, :E, 1, "A", :E}, 2, "B", {:B, :E, 3, "C", :E}}

  """
  @spec new(Enumerable.t()) :: tree
  def new(list) do
    Enum.reduce(list, empty(), fn {key, value}, acc ->
      {_result, new_tree} = insert(acc, key, value)

      new_tree
    end)
  end

  @doc """
  Adds many key-values to an existing map tree, and returns both the new tree and
  the number of new entries created.

  Returns a `{inserted, new_tree}` tuple when `inserted` is the number of newly created
  entries. Updating existing keys do not count. This is useful to keep track of size
  changes.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{1 => "A", 2 => "B"})
      iex> A.RBTree.Map.insert_many(tree, %{2 => "B", 3 => "C"})
      {1, {:B, {:B, :E, 1, "A", :E}, 2, "B", {:B, :E, 3, "C", :E}}}

  """
  @spec insert_many(tree(k, v), Enumerable.t()) :: {non_neg_integer, tree(k, v)}
        when k: key, v: value
  def insert_many(tree, list) do
    Enum.reduce(list, {0, tree}, fn {key, value}, {inserted, acc_tree} ->
      {result, new_tree} = insert(acc_tree, key, value)

      case result do
        :new -> {inserted + 1, new_tree}
        _ -> {inserted, new_tree}
      end
    end)
  end

  @doc """
  Finds and removes the value corresponding for the given `key` if exists in a map tree,
  and returns both that value and the new tree.

  Uses the deletion algorithm as described in
  [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf).

  ## Examples

      iex> tree = A.RBTree.Map.new(%{a: "A", b: "B", c: "C"})
      iex> {"B", _new_tree} = A.RBTree.Map.pop(tree, :b)
      {"B", {:B, :E, :a, "A", {:R, :E, :c, "C", :E}}}
      iex> :error = A.RBTree.Map.pop(tree, :d)
      :error

  """
  @spec pop(tree(k, v), k) :: {v, tree(k, v)} | :error
        when k: key, v: value
  defdelegate pop(tree, key), to: A.RBTree.Map.CurseDeletion

  @doc """
  Finds and removes the leftmost (smallest) key in a map tree.

  Returns both the key-value pair and the new tree.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{a: "A", b: "B", c: "C"})
      iex> {:a, "A", new_tree} = A.RBTree.Map.pop_min(tree)
      iex> new_tree
      {:B, {:R, :E, :b, "B", :E}, :c, "C", :E}
      iex> :error = A.RBTree.Map.pop_min(A.RBTree.Map.empty())
      :error

  """
  @spec pop_min(tree(k, v)) :: {k, v, tree(k, v)} | :error
        when k: key, v: value
  def pop_min(tree) do
    # TODO consider reimplement this as one pass? (optimization)
    case min(tree) do
      {key, value} ->
        {_value, new_tree} = pop(tree, key)
        {key, value, new_tree}

      nil ->
        :error
    end
  end

  @doc """
  Finds and removes the rightmost (largest) key in a map tree.

  Returns both the key-value pair and the new tree.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{a: "A", b: "B", c: "C"})
      iex> {:c, "C", new_tree} = A.RBTree.Map.pop_max(tree)
      iex> new_tree
      {:B, :E, :a, "A", {:R, :E, :b, "B", :E}}
      iex> :error = A.RBTree.Map.pop_max(A.RBTree.Map.empty())
      :error

  """
  @spec pop_max(tree(k, v)) :: {k, v, tree(k, v)} | :error
        when k: key, v: value
  def pop_max(tree) do
    # TODO consider reimplement this as one pass? (optimization)
    case max(tree) do
      {key, value} ->
        {_value, new_tree} = pop(tree, key)
        {key, value, new_tree}

      nil ->
        :error
    end
  end

  @doc """
  Returns the tree as a list.

  ## Examples

      iex> A.RBTree.Map.new([b: "B", c: "C", a: "A"]) |> A.RBTree.Map.to_list()
      [{:a, "A"}, {:b, "B"}, {:c, "C"}]
      iex> A.RBTree.Map.empty() |> A.RBTree.Map.to_list()
      []

  """
  @spec to_list(tree(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(root), do: to_list(root, [])

  # note: same as erlang gb_tree, not tail recursive. not sure it is beneficial?
  defp to_list(:E, acc), do: acc

  defp to_list({_color, left, xk, xv, right}, acc) do
    to_list(left, [{xk, xv} | to_list(right, acc)])
  end

  @doc """
  Computes the "length" of the tree by looping and counting each node.

  ## Examples

      iex> tree = A.RBTree.Map.new([{1,:a}, {2, :b}, {2.0, :c}, {3, :d}, {3.0, :e}, {3, :f}])
      iex> A.RBTree.Map.node_count(tree)
      3
      iex> A.RBTree.Map.node_count(A.RBTree.Map.empty())
      0

  """
  @spec node_count(tree) :: non_neg_integer
  def node_count(root), do: node_count(root, 0)

  defp node_count(:E, acc), do: acc

  defp node_count({_color, left, _xk, _yk, right}, acc) do
    node_count(left, node_count(right, acc + 1))
  end

  @doc """
  Finds the leftmost (smallest) element of a tree

  ## Examples

      iex> A.RBTree.Map.new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBTree.Map.max()
      {:d, "D"}
      iex> A.RBTree.Map.new([]) |> A.RBTree.Map.max()
      nil

  """
  @spec max(tree(k, v)) :: {k, v} | nil when k: key, v: value
  def max(:E), do: nil
  def max(t(_, _left, xk, xv, :E)), do: {xk, xv}
  def max(t(_, _left, _xk, _xv, right)), do: max(right)

  @doc """
  Finds the rightmost (largest) element of a tree

  ## Examples

      iex> A.RBTree.Map.new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBTree.Map.min()
      {:a, "A"}
      iex> A.RBTree.Map.new([]) |> A.RBTree.Map.min()
      nil

  """
  @spec min(tree(k, v)) :: {k, v} | nil when k: key, v: value
  def min(:E), do: nil
  def min(t(_, :E, xk, xv, _right)), do: {xk, xv}
  def min(t(_, left, _xk, _xv, _right)), do: min(left)

  @doc """
  Returns an iterator looping on a tree from left-to-right.

  The resulting iterator should be looped over using `next/1`.

  ## Examples

      iex> iterator = A.RBTree.Map.new([a: 22, b: 11]) |> A.RBTree.Map.iterator()
      iex> {k1, v1, iterator} = A.RBTree.Map.next(iterator)
      iex> {k2, v2, iterator} = A.RBTree.Map.next(iterator)
      iex> A.RBTree.Map.next(iterator)
      nil
      iex> [k1, v1, k2, v2]
      [:a, 22, :b, 11]

  """
  @spec iterator(tree(k, v)) :: iterator(k, v) when k: key, v: value
  def iterator(root) do
    iterator(root, [])
  end

  defp iterator(t(_color, :E, _xk, _xv, _right) = tree, acc), do: [tree | acc]
  defp iterator(t(_color, left, _xk, _xv, _right) = tree, acc), do: iterator(left, [tree | acc])
  defp iterator(:E, acc), do: acc

  @doc """
  Walk a tree using an iterator yielded by `iterator/1`.

  ## Examples

      iex> iterator = A.RBTree.Map.new([a: 22, b: 11]) |> A.RBTree.Map.iterator()
      iex> {k1, v1, iterator} = A.RBTree.Map.next(iterator)
      iex> {k2, v2, iterator} = A.RBTree.Map.next(iterator)
      iex> A.RBTree.Map.next(iterator)
      nil
      iex> [k1, v1, k2, v2]
      [:a, 22, :b, 11]

  """
  @spec iterator(iterator(k, v)) :: {k, v, iterator(k, v)} | nil when k: key, v: value
  def next([t(_color, _left, xk, xv, right) | acc]),
    do: {xk, xv, iterator(right, acc)}

  def next([]), do: nil

  @doc """
  Folds (reduces) the given tree from the left with a function. Requires an accumulator.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{22 => "22", 11 => "11", 33 => "33"})
      iex> A.RBTree.Map.foldl(tree, 0, fn key, _value, acc -> acc + key end)
      66
      iex> A.RBTree.Map.foldl(tree, [], fn key, value, acc -> [{key, value} | acc] end)
      [{33, "33"}, {22, "22"}, {11, "11"}]

  """
  def foldl(tree, acc, fun) when is_function(fun, 3) do
    do_foldl(tree, acc, fun)
  end

  defp do_foldl(t(_color, left, xk, xv, right), acc, fun) do
    fold_left = do_foldl(left, acc, fun)
    new_acc = fun.(xk, xv, fold_left)
    do_foldl(right, new_acc, fun)
  end

  defp do_foldl(:E, acc, _fun), do: acc

  @doc """
  Folds (reduces) the given tree from the right with a function. Requires an accumulator.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> tree = A.RBTree.Map.new(%{22 => "22", 11 => "11", 33 => "33"})
      iex> A.RBTree.Map.foldr(tree, 0, fn key, _value, acc -> acc + key end)
      66
      iex> A.RBTree.Map.foldr(tree, [], fn key, value, acc -> [{key, value} | acc] end)
      [{11, "11"}, {22, "22"}, {33, "33"}]

  """
  def foldr(tree, acc, fun) when is_function(fun, 3) do
    do_foldr(tree, acc, fun)
  end

  defp do_foldr(t(_color, left, xk, xv, right), acc, fun) do
    fold_right = do_foldr(right, acc, fun)
    new_acc = fun.(xk, xv, fold_right)
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
      {key, value, new_iterator} ->
        reduce_iterator(new_iterator, fun.({key, value}, acc), fun)

      nil ->
        {:done, acc}
    end
  end

  # Analysis functions

  def height(t(_color, left, _xk, _xv, right)) do
    1 + max(height(left), height(right))
  end

  def height(:E), do: 0

  def black_height(b(left, _xk, _xv, _right)), do: 1 + black_height(left)
  def black_height(r(left, _xk, _xv, _right)), do: black_height(left)
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

      iex> A.RBTree.Map.check_invariant(:E)
      {:ok, 0}
      iex> A.RBTree.Map.check_invariant({:B, :E, 1, nil, :E})
      {:ok, 1}
      iex> A.RBTree.Map.check_invariant({:R, :E, 1, nil, :E})
      {:error, "No red root allowed"}
      iex> A.RBTree.Map.check_invariant({:B, {:B, :E, 1, nil, :E}, 2, nil, :E})
      {:error, "Inconsistent black length"}
      iex> A.RBTree.Map.check_invariant({:B, {:R, {:R, :E, 1, nil, :E}, 2, nil, :E}, 3, nil, :E})
      {:error, "Red tree has red child"}
  """
  @spec check_invariant(tree) :: {:ok, non_neg_integer} | {:error, String.t()}
  def check_invariant(root) do
    case root do
      r(_a, _xk, _xv, _b) -> {:error, "No red root allowed"}
      _ -> do_check_invariant(root)
    end
  end

  defp do_check_invariant(:E), do: {:ok, 0}

  defp do_check_invariant(r(r(_a, _yk, _yv, _b), _xk, _xv, _right)),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant(r(_left, _xk, _xv, r(_a, _yk, _yv, _b))),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant(t(color, left, _xk, _xv, right)) do
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

  @spec balance_left(tree(k, v)) :: tree(k, v) when k: key, v: value
  defp balance_left(tree) do
    case tree do
      b(r(r(a, xk, xv, b), yk, yv, c), zk, zv, d) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      b(r(a, xk, xv, r(b, yk, yv, c)), zk, zv, d) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      balanced ->
        balanced
    end
  end

  @spec balance_right(tree(k, v)) :: tree(k, v) when k: key, v: value
  defp balance_right(tree) do
    case tree do
      b(a, xk, xv, r(r(b, yk, yv, c), zk, zv, d)) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      b(a, xk, xv, r(b, yk, yv, r(c, zk, zv, d))) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      balanced ->
        balanced
    end
  end
end
