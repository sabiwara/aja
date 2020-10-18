defmodule A.RBTree.CurseDeletion do
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
  @type tmp_tree(elem) ::
          :E | :EE | {tmp_color, tmp_tree(elem), elem, tmp_tree(elem)}
  @type key :: term
  @type value :: term
  @type elem :: term
  @type tmp_tree :: tmp_tree(elem)

  @spec map_pop(A.RBTree.tree({k, v}), k) :: {:ok, v, A.RBTree.tree({k, v})} | :error
        when k: key, v: value
  def map_pop(root, key) do
    case root |> redden() |> do_map_pop(key) do
      :error -> :error
      {:ok, value, new_root} -> {:ok, value, make_black(new_root)}
    end
  end

  @spec set_delete(A.RBTree.tree(el), el) :: {:ok, A.RBTree.tree(el)} | :error
        when el: elem
  def set_delete(root, value) do
    case root |> redden() |> do_set_delete(value) do
      :error -> :error
      {:ok, new_root} -> {:ok, make_black(new_root)}
    end
  end

  defp do_map_pop(tree, x) do
    case tree do
      :E ->
        :error

      # IMPORTANT: use `==`, not `===` (ordering)
      {:R, :E, {yk, yv}, :E} when x == yk ->
        {:ok, yv, :E}

      {:B, :E, {yk, yv}, :E} when x == yk ->
        {:ok, yv, :EE}

      {_color, :E, _y, :E} ->
        :error

      {:B, {:R, :E, y, :E}, {zk, zv}, :E} ->
        cond do
          x < zk ->
            case do_map_pop({:R, :E, y, :E}, x) do
              :error -> :error
              {:ok, value, tree} -> {:ok, value, {:B, tree, {zk, zv}, :E}}
            end

          x > zk ->
            :error

          true ->
            {:ok, zv, {:B, :E, y, :E}}
        end

      {color, a, {yk, yv}, b} ->
        cond do
          x < yk ->
            case do_map_pop(a, x) do
              :error -> :error
              {:ok, value, tree} -> {:ok, value, rotate({color, tree, {yk, yv}, b})}
            end

          x > yk ->
            case do_map_pop(b, x) do
              :error -> :error
              {:ok, value, tree} -> {:ok, value, rotate({color, a, {yk, yv}, tree})}
            end

          true ->
            {y2, b2} = min_del(b)
            new_tree = rotate({color, a, y2, b2})
            {:ok, yv, new_tree}
        end
    end
  end

  defp do_set_delete(tree, x) do
    case tree do
      :E ->
        :error

      # IMPORTANT: use `==`, not `===` (ordering)
      {:R, :E, y, :E} when x == y ->
        {:ok, :E}

      {:B, :E, y, :E} when x == y ->
        {:ok, :EE}

      {_color, :E, _y, :E} ->
        :error

      {:B, {:R, :E, y, :E}, z, :E} ->
        cond do
          x < z ->
            case do_set_delete({:R, :E, y, :E}, x) do
              :error -> :error
              {:ok, tree} -> {:ok, {:B, tree, z, :E}}
            end

          x > z ->
            :error

          true ->
            {:ok, {:B, :E, y, :E}}
        end

      {color, a, y, b} ->
        cond do
          x < y ->
            case do_set_delete(a, x) do
              :error -> :error
              {:ok, tree} -> {:ok, rotate({color, tree, y, b})}
            end

          x > y ->
            case do_set_delete(b, x) do
              :error -> :error
              {:ok, tree} -> {:ok, rotate({color, a, y, tree})}
            end

          true ->
            {y2, b2} = min_del(b)
            new_tree = rotate({color, a, y2, b2})
            {:ok, new_tree}
        end
    end
  end

  # delete :: Ord elt => elt -> Set elt -> Set elt
  # delete x s = del (redden s)
  #   where del E = E
  #     del (R E y E) | x == y = E
  #     | x /= y = T R E y E
  #     del (B E y E) | x == y = EE
  #     | x /= y = T B E y E
  #     del (B (R E y E) z E)
  #     | x < z = T B (del (R E y E)) z E
  #     | x == z = T B E y E
  #     | x > z = T B (R E y E) z E
  #     del (c a y b)
  #     | x < y = rotate c (del a) y b
  #     | x == y =
  #            let (y’,b’) = min_del b
  #            in rotate c a y’ b’
  #     | x > y = rotate c a y (del b)

  # Private functions

  @spec redden(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp redden({:B, {:B, _, _, _} = a, x, {:B, _, _, _} = b}), do: {:R, a, x, b}
  defp redden(tree), do: tree

  #     redden (B (B a x b) y (B c z d)) =
  #     T R (B a x b) y (B c z d)
  #     redden t = t

  @spec make_black(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp make_black({_color, l, x, r}), do: {:B, l, x, r}
  defp make_black(_empty), do: :E

  # probably less optimized but not sure about bubble
  @spec balance(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp balance(tree) do
    case tree do
      # original cases
      {:B, {:R, {:R, a, x, b}, y, c}, z, d} ->
        {:R, {:B, a, x, b}, y, {:B, c, z, d}}

      {:B, {:R, a, x, {:R, b, y, c}}, z, d} ->
        {:R, {:B, a, x, b}, y, {:B, c, z, d}}

      {:B, a, x, {:R, {:R, b, y, c}, z, d}} ->
        {:R, {:B, a, x, b}, y, {:B, c, z, d}}

      {:B, a, x, {:R, b, y, {:R, c, z, d}}} ->
        {:R, {:B, a, x, b}, y, {:B, c, z, d}}

      # extra deletion cases

      {:BB, {:R, a, x, {:R, b, y, c}}, z, d} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      {:BB, a, x, {:R, {:R, b, y, c}, z, d}} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      # default
      balanced ->
        balanced
    end
  end

  @spec rotate(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp rotate(tree) do
    case tree do
      # rotate R (BB a x b) y (B c z d) = balance B (R (B a x b) y c) z d
      {:R, {:BB, a, x, b}, y, {:B, c, z, d}} ->
        balance({:B, {:R, {:B, a, x, b}, y, c}, z, d})

      # rotate R EE y (B c z d) = balance B (R E y c) z d
      {:R, :EE, y, {:B, c, z, d}} ->
        balance({:B, {:R, :E, y, c}, z, d})

      # rotate R (B a x b) y (BB c z d) = balance B a x (R b y (B c z d))
      {:R, {:B, a, x, b}, y, {:BB, c, z, d}} ->
        balance({:B, a, x, {:R, b, y, {:B, c, z, d}}})

      # rotate R (B a x b) y EE = balance B a x (R b y E)
      {:R, {:B, a, x, b}, y, :EE} ->
        balance({:B, a, x, {:R, b, y, :E}})

      # rotate B (BB a x b) y (B c z d) = balance BB (R (B a x b) y c) z d
      {:B, {:BB, a, x, b}, y, {:B, c, z, d}} ->
        balance({:BB, {:R, {:B, a, x, b}, y, c}, z, d})

      # rotate B EE y (B c z d) = balance BB (R E y c) z d
      {:B, :EE, y, {:B, c, z, d}} ->
        balance({:BB, {:R, :E, y, c}, z, d})

      # rotate B (B a x b) y (BB c z d) = balance BB a x (R b y (B c z d))
      {:B, {:B, a, x, b}, y, {:BB, c, z, d}} ->
        balance({:BB, a, x, {:R, b, y, {:B, c, z, d}}})

      # rotate B (B a x b) y EE = balance BB a x (R b y E)
      {:B, {:B, a, x, b}, y, :EE} ->
        balance({:BB, a, x, {:R, b, y, :E}})

      # rotate B (BB a w b) x (R (B c y d) z e) = B (balance B (R (B a w b) x c) y d) z e
      {:B, {:BB, a, w, b}, x, {:R, {:B, c, y, d}, z, e}} ->
        {:B, balance({:B, {:R, {:B, a, w, b}, x, c}, y, d}), z, e}

      # rotate B EE x (R (B c y d) z e) = B (balance B (R E x c) y d) z e
      {:B, :EE, x, {:R, {:B, c, y, d}, z, e}} ->
        {:B, balance({:B, {:R, :E, x, c}, y, d}), z, e}

      # rotate B (R a w (B b x c)) y (BB d z e) = B a w (balance B b x (R c y (B d z e)))
      {:B, {:R, a, w, {:B, b, x, c}}, y, {:BB, d, z, e}} ->
        {:B, a, w, balance({:B, b, x, {:R, c, y, {:B, d, z, e}}})}

      # rotate B (R a w (B b x c)) y EE = B a w (balance B b x (R c y E))
      {:B, {:R, a, w, {:B, b, x, c}}, y, :EE} ->
        {:B, a, w, balance({:B, b, x, {:R, c, y, :E}})}

      # rotate color a x b = T color a x b
      _ ->
        tree
    end
  end

  defp min_del({:R, :E, x, :E}), do: {x, :E}
  defp min_del({:B, :E, x, :E}), do: {x, :EE}
  defp min_del({:B, :E, x, {:R, :E, y, :E}}), do: {x, {:B, :E, y, :E}}

  defp min_del({color, a, x, b}) do
    {x2, a2} = min_del(a)
    {x2, rotate({color, a2, x, b})}
  end

  # min_del (R E x E) = (x, E)
  # min_del (B E x E) = (x, EE)
  # min_del (B E x (R E y E)) = (x, T B E y E)
  # min_del (c a x b) = let (x’,a’) = min_del a
  #                           in (x’,rotate c a’ x b)
end
