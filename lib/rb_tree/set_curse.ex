defmodule A.RBTree.Set.CurseDeletion do
  @moduledoc false

  # Deletion algorithm as described in
  # [Deletion: The curse of the red-black tree](http://matt.might.net/papers/germane2014deletion.pdf)
  # It involves temporary trees with one more color: double-black (both nodes and leafs).
  # Those should disappear once they have been rebalanced thoug to become regular red-black trees.

  @compile {:inline, delete: 2, balance: 1, rotate: 1, make_black: 1, redden: 1}

  @typedoc """
  :R -> red
  :B -> black
  :BB -> double black (temporary)
  """
  @type tmp_color :: :R | :B | :BB

  # empty | double black empty | tree
  @type tmp_tree(elem) :: :E | :EE | {tmp_color, tmp_tree(elem), elem, tmp_tree(elem)}
  @type element :: term
  @type tmp_tree :: tmp_tree(element)

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

  defmacrop bb(left, elem, right) do
    quote do
      {:BB, unquote(left), unquote(elem), unquote(right)}
    end
  end

  @spec delete(A.RBTree.Set.tree(el), el) :: A.RBTree.Set.tree(el) | :error
        when el: element
  def delete(root, key) do
    case root |> redden() |> do_delete(key) do
      :error -> :error
      new_root -> make_black(new_root)
    end
  end

  defp do_delete(tree, x) do
    case tree do
      # IMPORTANT: use `==`, not `===` (ordering)
      r(:E, y, :E) when x == y ->
        :E

      b(:E, y, :E) when x == y ->
        :EE

      t(_color, :E, _y, :E) ->
        :error

      b(r(:E, y, :E), z, :E) ->
        cond do
          x < z ->
            case do_delete(r(:E, y, :E), x) do
              :error -> :error
              tree -> b(tree, z, :E)
            end

          x > z ->
            :error

          true ->
            b(:E, y, :E)
        end

      t(color, a, y, b) ->
        cond do
          x < y ->
            case do_delete(a, x) do
              :error -> :error
              tree -> rotate(t(color, tree, y, b))
            end

          x > y ->
            case do_delete(b, x) do
              :error -> :error
              tree -> rotate(t(color, a, y, tree))
            end

          true ->
            {y2, b2} = min_del(b)
            new_tree = rotate(t(color, a, y2, b2))
            new_tree
        end

      :E ->
        :error
    end
  end

  # Private functions

  @spec redden(tmp_tree(el)) :: tmp_tree(el) when el: element
  defp redden(b(b(_, _, _) = a, x, b(_, _, _) = b)),
    do: r(a, x, b)

  defp redden(tree), do: tree

  @spec make_black(tmp_tree(el)) :: tmp_tree(el) when el: element
  defp make_black(t(_color, l, x, r)), do: b(l, x, r)
  defp make_black(_empty), do: :E

  # probably less optimized but not sure about bubble
  @spec balance(tmp_tree(el)) :: tmp_tree(el) when el: element
  defp balance(tree) do
    case tree do
      # original cases
      b(r(r(a, x, b), y, c), z, d) ->
        r(b(a, x, b), y, b(c, z, d))

      b(r(a, x, r(b, y, c)), z, d) ->
        r(b(a, x, b), y, b(c, z, d))

      b(a, x, r(r(b, y, c), z, d)) ->
        r(b(a, x, b), y, b(c, z, d))

      b(a, x, r(b, y, r(c, z, d))) ->
        r(b(a, x, b), y, b(c, z, d))

      # extra deletion cases

      bb(r(a, x, r(b, y, c)), z, d) ->
        b(b(a, x, b), y, b(c, z, d))

      bb(a, x, r(r(b, y, c), z, d)) ->
        b(b(a, x, b), y, b(c, z, d))

      # default
      balanced ->
        balanced
    end
  end

  @spec rotate(tmp_tree(el)) :: tmp_tree(el) when el: element
  defp rotate(tree) do
    case tree do
      # rotate R (BB a x b) y (B c z d) = balance B (R (B a x b) y c) z d
      r(bb(a, x, b), y, b(c, z, d)) ->
        balance(b(r(b(a, x, b), y, c), z, d))

      # rotate R EE y (B c z d) = balance B (R E y c) z d
      r(:EE, y, b(c, z, d)) ->
        balance(b(r(:E, y, c), z, d))

      # rotate R (B a x b) y (BB c z d) = balance B a x (R b y (B c z d))
      r(b(a, x, b), y, bb(c, z, d)) ->
        balance(b(a, x, r(b, y, b(c, z, d))))

      # rotate R (B a x b) y EE = balance B a x (R b y E)
      r(b(a, x, b), y, :EE) ->
        balance(b(a, x, r(b, y, :E)))

      # rotate B (BB a x b) y (B c z d) = balance BB (R (B a x b) y c) z d
      b(bb(a, x, b), y, b(c, z, d)) ->
        balance(bb(r(b(a, x, b), y, c), z, d))

      # rotate B EE y (B c z d) = balance BB (R E y c) z d
      b(:EE, y, b(c, z, d)) ->
        balance(bb(r(:E, y, c), z, d))

      # rotate B (B a x b) y (BB c z d) = balance BB a x (R b y (B c z d))
      b(b(a, x, b), y, bb(c, z, d)) ->
        balance(bb(a, x, r(b, y, b(c, z, d))))

      # rotate B (B a x b) y EE = balance BB a x (R b y E)
      b(b(a, x, b), y, :EE) ->
        balance(bb(a, x, r(b, y, :E)))

      # rotate B (BB a w b) x (R (B c y d) z e) = B (balance B (R (B a w b) x c) y d) z e
      b(bb(a, w, b), x, r(b(c, y, d), z, e)) ->
        b(balance(b(r(b(a, w, b), x, c), y, d)), z, e)

      # rotate B EE x (R (B c y d) z e) = B (balance B (R E x c) y d) z e
      b(:EE, x, r(b(c, y, d), z, e)) ->
        b(balance(b(r(:E, x, c), y, d)), z, e)

      # rotate B (R a w (B b x c)) y (BB d z e) = B a w (balance B b x (R c y (B d z e)))
      b(r(a, w, b(b, x, c)), y, bb(d, z, e)) ->
        b(a, w, balance(b(b, x, r(c, y, b(d, z, e)))))

      # rotate B (R a w (B b x c)) y EE = B a w (balance B b x (R c y E))
      b(r(a, w, b(b, x, c)), y, :EE) ->
        b(a, w, balance(b(b, x, r(c, y, :E))))

      # rotate color a x b = T color a x b
      _ ->
        tree
    end
  end

  defp min_del(r(:E, x, :E)), do: {x, :E}
  defp min_del(b(:E, x, :E)), do: {x, :EE}
  defp min_del(b(:E, x, r(:E, y, :E))), do: {x, b(:E, y, :E)}

  defp min_del(t(color, a, x, b)) do
    {x2, a2} = min_del(a)
    {x2, rotate(t(color, a2, x, b))}
  end
end
