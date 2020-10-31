defmodule A.RBTree.Map.CurseDeletion do
  @moduledoc false

  # Deletion algorithm as described in
  # [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf)
  # It involves temporary trees with one more color: double-black (both nodes and leafs).
  # Those should disappear once they have been rebalanced thoug to become regular red-black trees.

  @typedoc """
  :R -> red
  :B -> black
  :BB -> double black (temporary)
  """
  @type tmp_color :: :R | :B | :BB

  # empty | double black empty | tree
  @type tmp_tree(key, value) ::
          :E | :EE | {tmp_color, tmp_tree(key, value), key, value, tmp_tree(key, value)}
  @type key :: term
  @type value :: term
  @type tmp_tree :: tmp_tree(key, value)

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

  defmacrop bb(left, key, value, right) do
    quote do
      {:BB, unquote(left), unquote(key), unquote(value), unquote(right)}
    end
  end

  @spec pop(A.RBTree.Map.tree(k, v), k) :: {v, A.RBTree.Map.tree(k, v)} | :error
        when k: key, v: value
  def pop(root, key) do
    case root |> redden() |> do_pop(key) do
      :error -> :error
      {value, new_root} -> {value, make_black(new_root)}
    end
  end

  defp do_pop(tree, x) do
    case tree do
      # IMPORTANT: use `==`, not `===` (ordering)
      r(:E, yk, yv, :E) when x == yk ->
        {yv, :E}

      b(:E, yk, yv, :E) when x == yk ->
        {yv, :EE}

      t(_color, :E, _yk, _yv, :E) ->
        :error

      b(r(:E, yk, yv, :E), zk, zv, :E) ->
        cond do
          x < zk ->
            case do_pop(r(:E, yk, yv, :E), x) do
              {value, tree} -> {value, b(tree, zk, zv, :E)}
              :error -> :error
            end

          x > zk ->
            :error

          true ->
            {zv, b(:E, yk, yv, :E)}
        end

      t(color, a, yk, yv, b) ->
        cond do
          x < yk ->
            case do_pop(a, x) do
              {value, tree} -> {value, rotate(t(color, tree, yk, yv, b))}
              :error -> :error
            end

          x > yk ->
            case do_pop(b, x) do
              {value, tree} -> {value, rotate(t(color, a, yk, yv, tree))}
              :error -> :error
            end

          true ->
            {yk2, yv2, b2} = min_del(b)
            new_tree = rotate(t(color, a, yk2, yv2, b2))
            {yv, new_tree}
        end

      :E ->
        :error
    end
  end

  # Private functions

  @spec redden(tmp_tree(k, v)) :: tmp_tree(k, v) when k: key, v: value
  defp redden(b(b(_, _, _, _) = a, xk, xv, b(_, _, _, _) = b)),
    do: r(a, xk, xv, b)

  defp redden(tree), do: tree

  @spec make_black(tmp_tree(k, v)) :: tmp_tree(k, v) when k: key, v: value
  defp make_black(t(_color, l, xk, xv, r)), do: b(l, xk, xv, r)
  defp make_black(_empty), do: :E

  # probably less optimized but not sure about bubble
  @spec balance(tmp_tree(k, v)) :: tmp_tree(k, v) when k: key, v: value
  defp balance(tree) do
    case tree do
      # original cases
      b(r(r(a, xk, xv, b), yk, yv, c), zk, zv, d) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      b(r(a, xk, xv, r(b, yk, yv, c)), zk, zv, d) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      b(a, xk, xv, r(r(b, yk, yv, c), zk, zv, d)) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      b(a, xk, xv, r(b, yk, yv, r(c, zk, zv, d))) ->
        r(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      # extra deletion cases

      bb(r(a, xk, xv, r(b, yk, yv, c)), zk, zv, d) ->
        b(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      bb(a, xk, xv, r(r(b, yk, yv, c), zk, zv, d)) ->
        b(b(a, xk, xv, b), yk, yv, b(c, zk, zv, d))

      # default
      balanced ->
        balanced
    end
  end

  @spec rotate(tmp_tree(k, v)) :: tmp_tree(k, v) when k: key, v: value
  defp rotate(tree) do
    case tree do
      # rotate R (BB a x b) y (B c z d) = balance B (R (B a x b) y c) z d
      r(bb(a, xk, xv, b), yk, yv, b(c, zk, zv, d)) ->
        balance(b(r(b(a, xk, xv, b), yk, yv, c), zk, zv, d))

      # rotate R EE y (B c z d) = balance B (R E y c) z d
      r(:EE, yk, yv, b(c, zk, zv, d)) ->
        balance(b(r(:E, yk, yv, c), zk, zv, d))

      # rotate R (B a x b) y (BB c z d) = balance B a x (R b y (B c z d))
      r(b(a, xk, xv, b), yk, yv, bb(c, zk, zv, d)) ->
        balance(b(a, xk, xv, r(b, yk, yv, b(c, zk, zv, d))))

      # rotate R (B a x b) y EE = balance B a x (R b y E)
      r(b(a, xk, xv, b), yk, yv, :EE) ->
        balance(b(a, xk, xv, r(b, yk, yv, :E)))

      # rotate B (BB a x b) y (B c z d) = balance BB (R (B a x b) y c) z d
      b(bb(a, xk, xv, b), yk, yv, b(c, zk, zv, d)) ->
        balance(bb(r(b(a, xk, xv, b), yk, yv, c), zk, zv, d))

      # rotate B EE y (B c z d) = balance BB (R E y c) z d
      b(:EE, yk, yv, b(c, zk, zv, d)) ->
        balance(bb(r(:E, yk, yv, c), zk, zv, d))

      # rotate B (B a x b) y (BB c z d) = balance BB a x (R b y (B c z d))
      b(b(a, xk, xv, b), yk, yv, bb(c, zk, zv, d)) ->
        balance(bb(a, xk, xv, r(b, yk, yv, b(c, zk, zv, d))))

      # rotate B (B a x b) y EE = balance BB a x (R b y E)
      b(b(a, xk, xv, b), yk, yv, :EE) ->
        balance(bb(a, xk, xv, r(b, yk, yv, :E)))

      # rotate B (BB a w b) x (R (B c y d) z e) = B (balance B (R (B a w b) x c) y d) z e
      b(bb(a, wk, wv, b), xk, xv, r(b(c, yk, yv, d), zk, zv, e)) ->
        b(balance(b(r(b(a, wk, wv, b), xk, xv, c), yk, yv, d)), zk, zv, e)

      # rotate B EE x (R (B c y d) z e) = B (balance B (R E x c) y d) z e
      b(:EE, xk, xv, r(b(c, yk, yv, d), zk, zv, e)) ->
        b(balance(b(r(:E, xk, xv, c), yk, yv, d)), zk, zv, e)

      # rotate B (R a w (B b x c)) y (BB d z e) = B a w (balance B b x (R c y (B d z e)))
      b(r(a, wk, wv, b(b, xk, xv, c)), yk, yv, bb(d, zk, zv, e)) ->
        b(a, wk, wv, balance(b(b, xk, xv, r(c, yk, yv, b(d, zk, zv, e)))))

      # rotate B (R a w (B b x c)) y EE = B a w (balance B b x (R c y E))
      b(r(a, wk, wv, b(b, xk, xv, c)), yk, yv, :EE) ->
        b(a, wk, wv, balance(b(b, xk, xv, r(c, yk, yv, :E))))

      # rotate color a x b = T color a x b
      _ ->
        tree
    end
  end

  defp min_del(r(:E, xk, xv, :E)), do: {xk, xv, :E}
  defp min_del(b(:E, xk, xv, :E)), do: {xk, xv, :EE}
  defp min_del(b(:E, xk, xv, r(:E, yk, yv, :E))), do: {xk, xv, b(:E, yk, yv, :E)}

  defp min_del(t(color, a, xk, xv, b)) do
    {xk2, xv2, a2} = min_del(a)
    {xk2, xv2, rotate(t(color, a2, xk, xv, b))}
  end
end
