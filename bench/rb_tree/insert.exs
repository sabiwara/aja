defmodule Bench.RBTree.Insert do
  @moduledoc ~S"""
  Comparing insertion performance between `A.RBTree` and `:gb_trees`.

  Red-black trees are faster by a factor of roughly 2 ??

    ##### With input n = 10 #####
    Name                ips        average  deviation         median         99th %
    A.RBTree       549.98 K        1.82 μs  ±1062.22%        1.63 μs        3.70 μs
    :gb_trees      383.18 K        2.61 μs   ±623.96%        2.41 μs        4.34 μs

    Comparison:
    A.RBTree       549.98 K
    :gb_trees      383.18 K - 1.44x slower +0.79 μs

    ##### With input n = 1000 #####
    Name                ips        average  deviation         median         99th %
    A.RBTree         1.90 K        0.53 ms    ±10.33%        0.51 ms        0.74 ms
    :gb_trees        0.83 K        1.20 ms     ±7.88%        1.19 ms        1.48 ms

    Comparison:
    A.RBTree         1.90 K
    :gb_trees        0.83 K - 2.27x slower +0.67 ms

    ##### With input n = 100000 #####
    Name                ips        average  deviation         median         99th %
    A.RBTree          11.00       90.88 ms     ±4.59%       91.40 ms      103.73 ms
    :gb_trees          4.17      240.05 ms     ±3.92%      237.10 ms      274.53 ms

    Comparison:
    A.RBTree          11.00
    :gb_trees          4.17 - 2.64x slower +149.17 ms

  """

  def insert_all_gb(n) do
    # `insert/3` is not really an equivalent (unsafe), using `enter/3`
    Enum.reduce(1..n, :gb_trees.empty(), fn i, acc -> :gb_trees.enter(i, i, acc) end)
  end

  def empty_rb, do: {0, A.RBTree.empty()}

  # keeping track of the size to be fair
  def insert_rb({size, root}, k, v) do
    case A.RBTree.map_insert(root, k, v) do
      {:new, new_root} -> {size + 1, new_root}
      {{:overwrite, _}, new_root} -> {size, new_root}
    end
  end

  def insert_all_rb(n) do
    Enum.reduce(1..n, empty_rb(), fn i, acc -> insert_rb(acc, i, i) end)
  end

  def inputs() do
    for n <- [10, 1000, 100_000], do: {"n = #{n}", n}
  end

  def run() do
    Benchee.run(
      [
        {":gb_trees", &insert_all_gb/1},
        {"A.RBTree", &insert_all_rb/1}
      ],
      inputs: inputs()
    )
  end
end

Bench.RBTree.Insert.run()
