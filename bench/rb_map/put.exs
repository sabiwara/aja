defmodule Bench.RBMap.Put do
  @moduledoc ~S"""
  Comparing insertion performance between `A.RBMap` and the built-ins `Map` and `:gb_trees`.

  Result:
  - it is about 2~4x slower than a built-in map
  - it is about 1.5~2x faster than gb trees

      ##### With input n = 10 #####
      Name                ips        average  deviation         median         99th %
      Map           1639.60 K        0.61 μs  ±5207.95%        0.47 μs        0.87 μs
      A.RBMap        466.52 K        2.14 μs   ±746.19%        1.92 μs        3.24 μs
      :gb_trees      381.56 K        2.62 μs   ±618.50%        2.45 μs        3.38 μs

      Comparison:
      Map           1639.60 K
      A.RBMap        466.52 K - 3.51x slower +1.53 μs
      :gb_trees      381.56 K - 4.30x slower +2.01 μs

      ##### With input n = 1000 #####
      Name                ips        average  deviation         median         99th %
      Map              6.64 K      150.63 μs    ±20.22%      137.92 μs      240.24 μs
      A.RBMap          1.78 K      561.55 μs    ±12.24%      544.49 μs      795.55 μs
      :gb_trees        0.83 K     1200.28 μs     ±5.76%     1198.52 μs     1421.47 μs

      Comparison:
      Map              6.64 K
      A.RBMap          1.78 K - 3.73x slower +410.92 μs
      :gb_trees        0.83 K - 7.97x slower +1049.65 μs

      ##### With input n = 100000 #####
      Name                ips        average  deviation         median         99th %
      Map               20.90       47.84 ms    ±12.47%       51.12 ms       70.33 ms
      A.RBMap           10.89       91.80 ms     ±3.96%       92.31 ms       99.54 ms
      :gb_trees          4.25      235.41 ms     ±0.69%      235.52 ms      238.09 ms

      Comparison:
      Map               20.90
      A.RBMap           10.89 - 1.92x slower +43.96 ms
      :gb_trees          4.25 - 4.92x slower +187.57 ms

  """

  def insert_all_gb(n) do
    # `insert/3` is not really an equivalent (unsafe), using `enter/3`
    Enum.reduce(1..n, :gb_trees.empty(), fn i, acc -> :gb_trees.enter(i, i, acc) end)
  end

  def put_all_map(n) do
    Enum.reduce(1..n, Map.new(), fn i, acc -> Map.put(acc, i, i) end)
  end

  def put_all_rb(n) do
    Enum.reduce(1..n, A.RBMap.new(), fn i, acc -> A.RBMap.put(acc, i, i) end)
  end

  def inputs() do
    for n <- [10, 1000, 100_000], do: {"n = #{n}", n}
  end

  def run() do
    Benchee.run(
      [
        {":gb_trees", &insert_all_gb/1},
        {"Map", &put_all_map/1},
        {"A.RBMap", &put_all_rb/1}
      ],
      inputs: inputs()
    )
  end
end

Bench.RBMap.Put.run()
