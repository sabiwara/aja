defmodule A.RBTree do
  @moduledoc ~S"""
  A low-level implementation of a Red-Black Tree, used under the hood in `A.RBMap`, `A.RBSet` and `A.OrdMap`.

  Implementation following Chris Okasaki's "Purely Functional Data Structures",
  with the delete method as described in
  [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf)
  from German and Might.

  It should perform significantly better than built-in `:gb_trees` and `:gb_sets` (see benchmarks).

  ## Disclaimer

  This module is the low-level implementation behind other data structures, it is NOT meant to be used directly.

  If you want something ready to use, you should check `A.RBMap` and `A.RBSet` (or maybe `A.OrdMap`).

  Probably the only case you might be interested in `A.RBTree` itself is if you want to implement
  your own data structures on the top of it, or out of curiosity.

  It implements both a Map API and a Set API, both should not be mixed.

  ## Map API

      iex> A.RBTree.map_new([])
      :E
      iex> map = A.RBTree.map_new([b: "B", c: "C", a: "A"])
      {:B, {:R, :E, {:a, "A"}, :E}, {:b, "B"}, {:R, :E, {:c, "C"}, :E}}
      iex> A.RBTree.map_fetch(map, :c)
      {:ok, "C"}
      iex> {:new, _new_map} = A.RBTree.map_insert(map, :bar, "BAR")
      {:new, {:B, {:B, {:R, :E, {:a, "A"}, :E}, {:b, "B"}, :E}, {:bar, "BAR"}, {:B, :E, {:c, "C"}, :E}}}
      iex> {:ok, "B", _new_map} = A.RBTree.map_pop(map, :b)
      {:ok, "B", {:B, {:R, :E, {:a, "A"}, :E}, {:c, "C"}, :E}}
      iex> A.RBTree.map_pop(map, :bar)
      :error
      iex> A.RBTree.map_new([b: "B", x: "X", c: "C", a: "A"]) |> A.RBTree.to_list()
      [a: "A", b: "B", c: "C", x: "X"]

  ## Set API

      iex> A.RBTree.set_new([])
      :E
      iex> set = A.RBTree.set_new([2.0, 3, 2, 1, 3, 3])
      {:B, {:R, :E, 1, :E}, 2, {:R, :E, 3, :E}}
      iex> A.RBTree.set_member?(set, 3)
      true
      iex> {:new, _new_set} = A.RBTree.set_insert(set, 2.5)
      {:new, {:B, {:B, {:R, :E, 1, :E}, 2, :E}, 2.5, {:B, :E, 3, :E}}}
      iex> {:ok, _new_set} = A.RBTree.set_delete(set, 2)
      {:ok, {:B, {:R, :E, 1, :E}, 3, :E}}
      iex> A.RBTree.set_delete(set, 4)
      :error
      iex> A.RBTree.set_new([9, 8, 8, 7, 4, 1, 1, 2, 3, 3, 3, 9, 5, 6]) |> A.RBTree.to_list()
      [1, 2, 3, 4, 5, 6, 7, 8, 9]

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

  Unlike regular maps, `A.RBTree`s only uses ordering for key comparisons,
  meaning integers and floats are indistiguinshable as keys.

      iex> %{1 => "一", 2 => "二"} |> Map.fetch(2)
      {:ok, "二"}
      iex> %{1 => "一", 2 => "二"} |> Map.fetch(2.0)
      :error
      iex> A.RBTree.map_new(%{1 => "一", 2 => "二"}) |> A.RBTree.map_fetch(2)
      {:ok, "二"}
      iex> A.RBTree.map_new(%{1 => "一", 2 => "二"}) |> A.RBTree.map_fetch(2.0)
      {:ok, "二"}

  Erlang's `:gb_trees` module works the same.
  """

  # TODO: inline what is relevant
  # WARNING: be careful with non-tail recursive functions looping on the full tree!
  @compile {:inline,
            balance_left: 1,
            balance_right: 1,
            map_fetch: 2,
            map_insert: 3,
            set_member?: 2,
            set_insert: 2,
            max: 1,
            min: 1}

  @type color :: :R | :B
  @type tree(elem) :: :E | {color, tree(elem), {key, value}, tree(elem)}
  @type iterator(elem) :: [tree(elem)]
  @type key :: term
  @type value :: term
  @type elem :: term
  @type tree :: tree(elem)

  @spec empty :: tree
  def empty, do: :E

  # MAP API

  @doc """
  Finds the value corresponding to the given `key` if exists.

  ## Examples

      iex> tree = A.RBTree.map_new(%{a: "A", b: "B", c: "C"})
      iex> A.RBTree.map_fetch(tree, :b)
      {:ok, "B"}
      iex> A.RBTree.map_fetch(tree, :d)
      :error

  """
  @spec map_fetch(tree({k, v}), k) :: v when k: key, v: value
  def map_fetch(:E, _key), do: :error

  def map_fetch({_color, left, {tree_key, _value}, _right}, key) when key < tree_key,
    do: map_fetch(left, key)

  def map_fetch({_color, _left, {tree_key, _value}, right}, key) when key > tree_key,
    do: map_fetch(right, key)

  def map_fetch({_color, _left, {_tree_key, value}, _right}, _key), do: {:ok, value}

  @doc """
  Inserts the key-value pair in a map tree and returns the updated tree.

  Returns a `{:new, new_tree}` tuple when the key was newly created.
  Returns a `{{:overwrite, previous_value}, new_tree}` tuple when the key
  was already present with the value `previous_value`.

  ## Examples

      iex> tree = A.RBTree.map_new(%{1 => "A", 3 => "C"})
      iex> A.RBTree.map_insert(tree, 2, "B")
      {:new, {:B, {:B, :E, {1, "A"}, :E}, {2, "B"}, {:B, :E, {3, "C"}, :E}}}
      iex> A.RBTree.map_insert(tree, 3, "C!!!")
      {{:overwrite, "C"}, {:B, :E, {1, "A"}, {:R, :E, {3, "C!!!"}, :E}}}

  """
  @spec map_insert(tree({k, v}), k, v) :: {:new | {:overwrite, v}, tree({k, v})}
        when k: key, v: value
  def map_insert(root, key, value) do
    {result, {_color, left, root_key_value, right}} = do_map_insert(root, key, value)
    new_root = {:B, left, root_key_value, right}

    {result, new_root}
  end

  defp do_map_insert(:E, key, value), do: {:new, {:R, :E, {key, value}, :E}}

  defp do_map_insert({color, left, {y_key, _y_value} = y, right}, key, value)
       when key < y_key do
    {kind, new_left} = do_map_insert(left, key, value)
    new_tree = balance_left({color, new_left, y, right})
    {kind, new_tree}
  end

  defp do_map_insert({color, left, {y_key, _y_value} = y, right}, key, value)
       when key > y_key do
    {kind, new_right} = do_map_insert(right, key, value)
    new_tree = balance_right({color, left, y, new_right})
    {kind, new_tree}
  end

  # note: in the case of numbers, the previous and new keys might be different (e.g. `1` and `1.0`)
  # we use the new one, meaning inserting `1.0` will overwrite `1`.
  defp do_map_insert({color, left, {_key, previous_value}, right}, key, value),
    do: {{:overwrite, previous_value}, {color, left, {key, value}, right}}

  @doc """
  Initializes a map tree from an enumerable.

  ## Examples

      iex> A.RBTree.map_new(%{1 => "A", 2 => "B", 3 => "C"})
      {:B, {:B, :E, {1, "A"}, :E}, {2, "B"}, {:B, :E, {3, "C"}, :E}}

  """
  @spec map_new(Enumerable.t()) :: tree
  def map_new(list) do
    Enum.reduce(list, empty(), fn {key, value}, acc ->
      {_result, new_tree} = map_insert(acc, key, value)

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

      iex> tree = A.RBTree.map_new(%{1 => "A", 2 => "B"})
      iex> A.RBTree.map_insert_many(tree, %{2 => "B", 3 => "C"})
      {1, {:B, {:B, :E, {1, "A"}, :E}, {2, "B"}, {:B, :E, {3, "C"}, :E}}}

  """
  @spec map_insert_many(tree({k, v}), Enumerable.t()) :: {non_neg_integer, tree({k, v})}
        when k: key, v: value
  def map_insert_many(tree, list) do
    Enum.reduce(list, {0, tree}, fn {key, value}, {inserted, acc_tree} ->
      {result, new_tree} = map_insert(acc_tree, key, value)

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

      iex> tree = A.RBTree.map_new(%{a: "A", b: "B", c: "C"})
      iex> {:ok, "B", _new_tree} = A.RBTree.map_pop(tree, :b)
      {:ok, "B", {:B, :E, {:a, "A"}, {:R, :E, {:c, "C"}, :E}}}
      iex> :error = A.RBTree.map_pop(tree, :d)
      :error

  """
  @spec map_pop(tree({k, v}), k) :: {:ok, v, tree({k, v})} | :error
        when k: key, v: value
  defdelegate map_pop(tree, key), to: A.RBTree.CurseDeletion

  @doc """
  Finds and removes the leftmost (smallest) key in a map tree.

  Returns both the key-value pair and the new tree.

  ## Examples

      iex> tree = A.RBTree.map_new(%{a: "A", b: "B", c: "C"})
      iex> {:ok, {:a, "A"}, new_tree} = A.RBTree.map_pop_min(tree)
      iex> new_tree
      {:B, {:R, :E, {:b, "B"}, :E}, {:c, "C"}, :E}
      iex> :error = A.RBTree.map_pop_min(A.RBTree.empty())
      :error

  """
  @spec map_pop_min(tree({k, v})) :: {:ok, {k, v}, tree({k, v})} | :error
        when k: key, v: value
  def map_pop_min(tree) do
    # TODO consider reimplement this as one pass? (optimization)
    case min(tree) do
      :error ->
        :error

      {:ok, {key, value}} ->
        {:ok, _value, new_tree} = map_pop(tree, key)
        {:ok, {key, value}, new_tree}
    end
  end

  @doc """
  Finds and removes the rightmost (largest) key in a map tree.

  Returns both the key-value pair and the new tree.

  ## Examples

      iex> tree = A.RBTree.map_new(%{a: "A", b: "B", c: "C"})
      iex> {:ok, {:c, "C"}, new_tree} = A.RBTree.map_pop_max(tree)
      iex> new_tree
      {:B, :E, {:a, "A"}, {:R, :E, {:b, "B"}, :E}}
      iex> :error = A.RBTree.map_pop_max(A.RBTree.empty())
      :error

  """
  @spec map_pop_max(tree({k, v})) :: {:ok, {k, v}, tree({k, v})} | :error
        when k: key, v: value
  def map_pop_max(tree) do
    # TODO consider reimplement this as one pass? (optimization)
    case max(tree) do
      :error ->
        :error

      {:ok, {key, value}} ->
        {:ok, _value, new_tree} = map_pop(tree, key)
        {:ok, {key, value}, new_tree}
    end
  end

  # SET API

  @doc """
  Checks the presence of a value in a set.

  Like all `A.RBTree` functions, uses `==/2` for comparison,
  not strict equality `===/2`.

  ## Examples

      iex> tree = A.RBTree.set_new([1, 2, 3])
      iex> A.RBTree.set_member?(tree, 2)
      true
      iex> A.RBTree.set_member?(tree, 4)
      false
      iex> A.RBTree.set_member?(tree, 2.0)
      true

  """
  @spec set_member?(tree(el), el) :: boolean when el: elem
  def set_member?(:E, _x), do: false

  def set_member?({_color, left, y, _right}, x) when x < y,
    do: set_member?(left, x)

  def set_member?({_color, _left, y, right}, x) when x > y,
    do: set_member?(right, x)

  def set_member?({_color, _left, _y, _right}, _x), do: true

  @doc """
  Inserts the value in a set tree and returns the updated tree.

  Returns a `{:new, new_tree}` tuple when the value was newly inserted.
  Returns a `{:overwrite, new_tree}` tuple when a non-striclty
  equal value was already present.

  Because `1.0` and `1` compare as equal values, inserting `1.0` can
  overwrite `1` and `new_tree` is going to be different.

  ## Examples

      iex> tree = A.RBTree.set_new([1, 3])
      iex> A.RBTree.set_insert(tree, 2)
      {:new, {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}}
      iex> A.RBTree.set_insert(tree, 3.0)
      {:overwrite, {:B, :E, 1, {:R, :E, 3.0, :E}}}

  """
  @spec set_insert(tree(el), el) :: {:new | :overwrite, tree(el)}
        when el: elem
  def set_insert(root, elem) do
    {result, {_color, left, x, right}} = do_set_insert(root, elem)
    new_root = {:B, left, x, right}

    {result, new_root}
  end

  defp do_set_insert(:E, x), do: {:new, {:R, :E, x, :E}}

  defp do_set_insert({color, left, y, right}, x) when x < y do
    {kind, new_left} = do_set_insert(left, x)
    new_tree = balance_left({color, new_left, y, right})
    {kind, new_tree}
  end

  defp do_set_insert({color, left, y, right}, x) when x > y do
    {kind, new_right} = do_set_insert(right, x)
    new_tree = balance_right({color, left, y, new_right})
    {kind, new_tree}
  end

  # note: in the case of numbers, the previous and new keys might be different (e.g. `1` and `1.0`)
  # we use the new one, meaning inserting `1.0` will overwrite `1`.
  defp do_set_insert({color, left, _y, right}, x),
    do: {:overwrite, {color, left, x, right}}

  @doc """
  Initializes a set tree from an enumerable.

  ## Examples

      iex> A.RBTree.set_new([3, 2, 1, 2, 3])
      {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}

  """
  @spec set_new(Enumerable.t()) :: tree
  def set_new(list) do
    Enum.reduce(list, empty(), fn elem, acc ->
      {_result, new_tree} = set_insert(acc, elem)
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

      iex> tree = A.RBTree.set_new([1, 2])
      iex> A.RBTree.set_insert_many(tree, [2, 2.0, 3, 3.0])
      {1, {:B, {:B, :E, 1, :E}, 2.0, {:B, :E, 3.0, :E}}}

  """
  @spec set_insert_many(tree(el), Enumerable.t()) :: {non_neg_integer, tree(el)}
        when el: elem
  def set_insert_many(tree, list) do
    Enum.reduce(list, {0, tree}, fn elem, {inserted, acc_tree} ->
      {result, new_tree} = set_insert(acc_tree, elem)

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

      iex> tree = A.RBTree.set_new([1, 2, 3, 4])
      iex> {:ok, _new_tree} = A.RBTree.set_delete(tree, 3)
      {:ok, {:B, {:B, :E, 1, :E}, 2, {:B, :E, 4, :E}}}
      iex> :error = A.RBTree.set_delete(tree, 0)
      :error

  """
  @spec set_delete(tree(el), el) :: {:ok, tree(el)} | :error when el: elem
  defdelegate set_delete(tree, value), to: A.RBTree.CurseDeletion

  @doc """
  Finds and removes the leftmost (smallest) element in a set tree.

  Returns both the element and the new tree.

  ## Examples

      iex> tree = A.RBTree.set_new([1, 2, 3, 4])
      iex> {:ok, 1, new_tree} = A.RBTree.set_pop_min(tree)
      iex> new_tree
      {:B, {:R, :E, 2, :E}, 3, {:R, :E, 4, :E}}
      iex> :error = A.RBTree.set_pop_min(A.RBTree.empty())
      :error

  """
  @spec set_pop_min(tree(el)) :: {:ok, el, tree(el)} | :error when el: elem
  def set_pop_min(tree) do
    case min(tree) do
      :error ->
        :error

      {:ok, value} ->
        {:ok, new_tree} = set_delete(tree, value)
        {:ok, value, new_tree}
    end
  end

  @doc """
  Finds and removes the rightmost (largest) element in a set tree.

  Returns both the element and the new tree.

  ## Examples

      iex> tree = A.RBTree.set_new([1, 2, 3, 4])
      iex> {:ok, 4, new_tree} = A.RBTree.set_pop_max(tree)
      iex> new_tree
      {:B, {:B, :E, 1, :E}, 2, {:B, :E, 3, :E}}
      iex> :error = A.RBTree.set_pop_max(A.RBTree.empty())
      :error

  """
  @spec set_pop_max(tree(el)) :: {:ok, el, tree(el)} | :error when el: elem
  def set_pop_max(tree) do
    case max(tree) do
      :error ->
        :error

      {:ok, value} ->
        {:ok, new_tree} = set_delete(tree, value)
        {:ok, value, new_tree}
    end
  end

  # COMMON API

  @doc """
  Returns the tree as a list.

  ## Examples

      iex> A.RBTree.set_new([3, 2, 2.0, 3, 3.0, 1, 3]) |> A.RBTree.to_list()
      [1, 2.0, 3]
      iex> A.RBTree.map_new([b: "B", c: "C", a: "A"]) |> A.RBTree.to_list()
      [{:a, "A"}, {:b, "B"}, {:c, "C"}]
      iex> A.RBTree.empty() |> A.RBTree.to_list()
      []

  """
  @spec to_list(tree(el)) :: [el] when el: elem
  def to_list(root), do: to_list(root, [])

  # note: same as erlang gb_tree, not tail recursive. not sure it is beneficial?
  defp to_list(:E, acc), do: acc

  defp to_list({_color, left, x, right}, acc) do
    to_list(left, [x | to_list(right, acc)])
  end

  @doc """
  Computes the "length" of the tree by looping and counting each node.

  ## Examples

      iex> tree = A.RBTree.set_new([1, 2, 2.0, 3, 3.0, 3])
      iex> A.RBTree.node_count(tree)
      3
      iex> A.RBTree.node_count(A.RBTree.empty())
      0

  """
  @spec node_count(tree(el)) :: non_neg_integer when el: elem
  def node_count(root), do: node_count(root, 0)

  defp node_count(:E, acc), do: acc

  defp node_count({_color, left, _x, right}, acc) do
    node_count(left, node_count(right, acc + 1))
  end

  @doc """
  Finds the leftmost (smallest) element of a tree

  ## Examples

      iex> A.RBTree.map_new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBTree.max()
      {:ok, {:d, "D"}}
      iex> A.RBTree.map_new([]) |> A.RBTree.max()
      :error

  """
  @spec max(tree(el)) :: {:ok, el} | :error when el: elem
  def max(:E), do: :error
  def max({_, _left, x, :E}), do: {:ok, x}
  def max({_, _left, _x, right}), do: max(right)

  @doc """
  Finds the rightmost (largest) element of a tree

  ## Examples

      iex> A.RBTree.map_new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBTree.min()
      {:ok, {:a, "A"}}
      iex> A.RBTree.map_new([]) |> A.RBTree.min()
      :error

  """
  @spec min(tree(el)) :: {:ok, el} | :error when el: elem
  def min(:E), do: :error
  def min({_, :E, x, _right}), do: {:ok, x}
  def min({_, left, _x, _right}), do: min(left)

  @doc """
  Returns an iterator looping on a tree from left-to-right.

  The resulting iterator should be looped over using `next/1`.

  ## Examples

      iex> iterator = A.RBTree.set_new([22, 11]) |> A.RBTree.iterator()
      iex> {i1, iterator} = A.RBTree.next(iterator)
      iex> {i2, iterator} = A.RBTree.next(iterator)
      iex> A.RBTree.next(iterator)
      nil
      iex> [i1, i2]
      [11, 22]

  """
  @spec iterator(tree(el)) :: iterator(el) when el: elem
  def iterator(root) do
    iterator(root, [])
  end

  defp iterator({_color, :E, _elem, _right} = tree, acc), do: [tree | acc]
  defp iterator({_color, left, _elem, _right} = tree, acc), do: iterator(left, [tree | acc])
  defp iterator(:E, acc), do: acc

  @doc """
  Walk a tree using an iterator yielded by `iterator/1`.

  ## Examples

      iex> iterator = A.RBTree.set_new([22, 11]) |> A.RBTree.iterator()
      iex> {i1, iterator} = A.RBTree.next(iterator)
      iex> {i2, iterator} = A.RBTree.next(iterator)
      iex> A.RBTree.next(iterator)
      nil
      iex> [i1, i2]
      [11, 22]

  """
  @spec iterator(iterator(el)) :: {el, iterator(el)} | nil when el: elem
  def next([{_color, _left, elem, right} | acc]),
    do: {elem, iterator(right, acc)}

  def next([]), do: nil

  @doc """
  Folds (reduces) the given tree from the left with a function. Requires an accumulator.

  ## Examples

      iex> A.RBTree.set_new([22, 11, 33]) |> A.RBTree.foldl(0, &+/2)
      66
      iex> A.RBTree.set_new([22, 11, 33]) |> A.RBTree.foldl([], &([2 * &1 | &2]))
      [66, 44, 22]

  """
  def foldl(tree, acc, fun) when is_function(fun, 2) do
    do_foldl(tree, acc, fun)
  end

  defp do_foldl(:E, acc, _fun), do: acc

  defp do_foldl({_color, left, x, right}, acc, fun) do
    fold_right = do_foldl(left, acc, fun)
    new_acc = fun.(x, fold_right)
    do_foldl(right, new_acc, fun)
  end

  @doc """
  Folds (reduces) the given tree from the right with a function. Requires an accumulator.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> A.RBTree.set_new([22, 11, 33]) |> A.RBTree.foldr(0, &+/2)
      66
      iex> A.RBTree.set_new([22, 11, 33]) |> A.RBTree.foldr([], &([2 * &1 | &2]))
      [22, 44, 66]

  """
  def foldr(tree, acc, fun) when is_function(fun, 2) do
    do_foldr(tree, acc, fun)
  end

  defp do_foldr(:E, acc, _fun), do: acc

  defp do_foldr({_color, left, x, right}, acc, fun) do
    fold_right = do_foldr(right, acc, fun)
    new_acc = fun.(x, fold_right)
    do_foldr(left, new_acc, fun)
  end

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

  def height(:E), do: 0

  def height({_color, left, _key_value, right}) do
    1 + max(height(left), height(right))
  end

  def black_height(:E), do: 0
  def black_height({:B, left, _x, _right}), do: 1 + black_height(left)
  def black_height({:R, left, _x, _right}), do: black_height(left)

  def check_invariant!(tree) do
    {:ok, _} = check_invariant(tree)
    tree
  end

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

      iex> A.RBTree.check_invariant(:E)
      {:ok, 0}
      iex> A.RBTree.check_invariant({:B, :E, {1, nil}, :E})
      {:ok, 1}
      iex> A.RBTree.check_invariant({:R, :E, {1, nil}, :E})
      {:error, "No red root allowed"}
      iex> A.RBTree.check_invariant({:B, {:B, :E, {1, nil}, :E}, {2, nil}, :E})
      {:error, "Inconsistent black length"}
      iex> A.RBTree.check_invariant({:B, {:R, {:R, :E, {1, nil}, :E}, {2, nil}, :E}, {3, nil}, :E})
      {:error, "Red tree has red child"}
  """
  @spec check_invariant(tree) :: {:ok, non_neg_integer} | {:error, String.t()}
  def check_invariant(root) do
    case root do
      {:R, _, _, _} -> {:error, "No red root allowed"}
      _ -> do_check_invariant(root)
    end
  end

  defp do_check_invariant(:E), do: {:ok, 0}

  defp do_check_invariant({:R, {:R, _, _, _}, _, _right}),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant({:R, _left, _, {:R, _, _, _}}),
    do: {:error, "Red tree has red child"}

  defp do_check_invariant({color, left, _, right}) do
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

  @spec balance_left(tree({k, v})) :: tree({k, v}) when k: key, v: value
  defp balance_left(tree) do
    case tree do
      {:B, {:R, {:R, a, x, b}, y, c}, z, d} -> {:R, {:B, a, x, b}, y, {:B, c, z, d}}
      {:B, {:R, a, x, {:R, b, y, c}}, z, d} -> {:R, {:B, a, x, b}, y, {:B, c, z, d}}
      balanced -> balanced
    end
  end

  @spec balance_right(tree({k, v})) :: tree({k, v}) when k: key, v: value
  defp balance_right(tree) do
    case tree do
      {:B, a, x, {:R, {:R, b, y, c}, z, d}} -> {:R, {:B, a, x, b}, y, {:B, c, z, d}}
      {:B, a, x, {:R, b, y, {:R, c, z, d}}} -> {:R, {:B, a, x, b}, y, {:B, c, z, d}}
      balanced -> balanced
    end
  end
end
