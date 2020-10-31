defmodule Bench.RBTree.Insert do
  def insert_all_gb(n) do
    # `insert/3` is not really an equivalent (unsafe), using `enter/3`
    Enum.reduce(1..n, :gb_trees.empty(), fn i, acc -> :gb_trees.enter(i, i, acc) end)
  end

  def empty_rb, do: {0, A.RBTree.Map.empty()}

  # keeping track of the size to be fair
  def insert_rb({size, root}, k, v) do
    case A.RBTree.Map.insert(root, k, v) do
      {:new, new_root} -> {size + 1, new_root}
      {:overwrite, new_root} -> {size, new_root}
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
        {"A.RBTree.Map", &insert_all_rb/1}
      ],
      inputs: inputs()
    )
  end
end

Bench.RBTree.Insert.run()
