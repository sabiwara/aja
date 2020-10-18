defmodule A.RBTree.MightDeletion do
  @moduledoc false

  # Deletion algorithm as described in this article by Matt Might:
  # http://matt.might.net/articles/red-black-delete/
  # It involves temporary trees with more colors.
  # Those should disappear once they have been rebalanced thoug to become regular red-black trees.

  @typedoc """
  :R -> red
  :B -> black
  :BB -> double black (temporary)
  :NB -> negative black (temporary)
  """
  @type tmp_color :: :R | :B | :BB | :NB

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
    case do_map_pop(root, key) do
      :error -> :error
      {:ok, value, new_root} -> {:ok, value, make_black(new_root)}
    end
  end

  defp do_map_pop(:E, _key), do: :error

  defp do_map_pop({color, a, {y, value} = yy, b} = tree, x) do
    cond do
      x < y ->
        case map_pop(a, x) do
          :error -> :error
          {:ok, popped, new_a} -> {:ok, popped, bubble({color, new_a, yy, b})}
        end

      x > y ->
        case map_pop(b, x) do
          :error -> :error
          {:ok, popped, new_b} -> {:ok, popped, bubble({color, a, yy, new_b})}
        end

      true ->
        {:ok, value, remove(tree)}
    end
  end

  # Private functions

  defp remove(tree) do
    case tree do
      {:R, :E, _, :E} ->
        :E

      {:B, :E, _, :E} ->
        :EE

      {:B, :E, _, {:R, a, x, b}} ->
        {:B, a, x, b}

      {:B, {:R, a, x, b}, _, :E} ->
        {:B, a, x, b}

      {color, a, _x, b} ->
        {:ok, max_elem} = A.RBTree.max(a)
        new_a = remove_max(a)
        bubble({color, new_a, max_elem, b})
    end
  end

  defp remove_max({_color, _left, _elem, :E} = tree), do: remove(tree)

  defp remove_max({color, left, elem, right}),
    do: bubble({color, left, elem, remove_max(right)})

  # will never redden empty tree
  @spec make_red(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp make_red({_color, l, x, r}), do: {:R, l, x, r}

  @spec make_black(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp make_black({_color, l, x, r}), do: {:B, l, x, r}
  defp make_black(_empty), do: :E

  @spec double_black?(tmp_tree) :: boolean
  defp double_black?(:EE), do: true
  defp double_black?({:BB, _, _, _}), do: true
  defp double_black?(_), do: false

  # double black cannot be any blacker
  @spec blacker_color(tmp_color) :: tmp_color
  defp blacker_color(:NB), do: :R
  defp blacker_color(:R), do: :B
  defp blacker_color(:B), do: :BB

  # negative black cannot be any redder
  @spec redder_color(tmp_color) :: tmp_color
  defp redder_color(:BB), do: :B
  defp redder_color(:B), do: :R
  defp redder_color(:R), do: :NB

  @spec make_redder(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp make_redder(:EE), do: :E
  defp make_redder({color, l, x, r}), do: {redder_color(color), l, x, r}

  # probably less optimized but not sure about bubble
  @spec balance_both(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp balance_both(tree) do
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
      {:BB, {:R, {:R, a, x, b}, y, c}, z, d} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      {:BB, {:R, a, x, {:R, b, y, c}}, z, d} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      {:BB, {:NB, {:B, _, _, _} = a, x, {:B, b, y, c}}, z, d} ->
        {:B, balance_both({:B, make_red(a), x, b}), y, {:B, c, z, d}}

      # extra deletion cases
      {:BB, a, x, {:R, {:R, b, y, c}, z, d}} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      {:BB, a, x, {:R, b, y, {:R, c, z, d}}} ->
        {:B, {:B, a, x, b}, y, {:B, c, z, d}}

      {:BB, a, x, {:NB, {:B, b, y, c}, z, {:B, _, _, _} = d}} ->
        {:B, {:B, a, x, b}, y, balance_both({:B, c, z, make_red(d)})}

      # default
      balanced ->
        balanced
    end
  end

  @spec bubble(tmp_tree(el)) :: tmp_tree(el) when el: elem
  defp bubble({color, l, x, r}) do
    # TODO figure out if we can only balance left/right, deletion not optimized
    # seems hard though when looking at:
    # https://github.com/sweirich/dth/blob/master/examples/red-black/MightRedBlackGADT.hs
    if double_black?(l) or double_black?(r) do
      balance_both({blacker_color(color), make_redder(l), x, make_redder(r)})
    else
      balance_both({color, l, x, r})
    end
  end
end
