defmodule Bench.RBSet.Put do
  @moduledoc ~S"""
  Comparing insertion performance between `A.RBSet` and the built-ins `Set` and `:gb_sets`.

  Result:
  - it is about 2~3x slower than a built-in MapSet
  - it is about 1.2~2.5x faster than gb sets

    ##### With input n = 10 #####
    Name               ips        average  deviation         median         99th %
    MapSet       1103.39 K        0.91 μs  ±2634.11%        0.76 μs        1.30 μs
    A.RBSet       498.90 K        2.00 μs  ±1033.80%        1.78 μs        3.09 μs
    :gb_sets      407.89 K        2.45 μs   ±605.83%        2.26 μs        3.62 μs

    Comparison:
    MapSet       1103.39 K
    A.RBSet       498.90 K - 2.21x slower +1.10 μs
    :gb_sets      407.89 K - 2.71x slower +1.55 μs

    ##### With input n = 1000 #####
    Name               ips        average  deviation         median         99th %
    MapSet          5.70 K      175.57 μs    ±22.40%      161.22 μs      306.09 μs
    A.RBSet         1.99 K      503.43 μs     ±9.58%      488.63 μs      692.13 μs
    :gb_sets        0.89 K     1117.48 μs     ±7.54%     1104.02 μs     1396.57 μs

    Comparison:
    MapSet          5.70 K
    A.RBSet         1.99 K - 2.87x slower +327.86 μs
    :gb_sets        0.89 K - 6.36x slower +941.91 μs

    ##### With input n = 100000 #####
    Name               ips        average  deviation         median         99th %
    MapSet           21.96       45.53 ms     ±8.73%       44.90 ms       62.11 ms
    A.RBSet          12.08       82.75 ms     ±3.05%       82.10 ms       95.08 ms
    :gb_sets          4.69      213.09 ms     ±1.64%      212.24 ms      220.11 ms

    Comparison:
    MapSet           21.96
    A.RBSet          12.08 - 1.82x slower +37.21 ms
    :gb_sets          4.69 - 4.68x slower +167.55 ms

  """

  def insert_all_gb(n) do
    Enum.reduce(1..n, :gb_sets.empty(), fn i, acc -> :gb_sets.add(i, acc) end)
  end

  def put_all_map(n) do
    Enum.reduce(1..n, MapSet.new(), fn i, acc -> MapSet.put(acc, i) end)
  end

  def put_all_rb(n) do
    Enum.reduce(1..n, A.RBSet.new(), fn i, acc -> A.RBSet.put(acc, i) end)
  end

  def inputs() do
    for n <- [10, 1000, 100_000], do: {"n = #{n}", n}
  end

  def run() do
    Benchee.run(
      [
        {":gb_sets", &insert_all_gb/1},
        {"MapSet", &put_all_map/1},
        {"A.RBSet", &put_all_rb/1}
      ],
      inputs: inputs()
    )
  end
end

Bench.RBSet.Put.run()
