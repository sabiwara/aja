defmodule Bench.OrdMap.Put do
  @moduledoc ~S"""

  `put/3` is significantly (~ 4x) slower for `A.OrdMap` than for `Map`:

    ##### With input n = 10 #####
    Name                   ips        average  deviation         median         99th %
    Map                 1.38 M        0.73 μs  ±2505.11%        0.58 μs        1.50 μs
    A.OrdMap        0.33 M        3.04 μs   ±622.41%        2.68 μs        8.21 μs

    Comparison:
    Map                 1.38 M
    A.OrdMap        0.33 M - 4.18x slower +2.31 μs

    ##### With input n = 1000 #####
    Name                   ips        average  deviation         median         99th %
    Map                 5.24 K      190.95 μs    ±27.45%      169.80 μs      339.61 μs
    A.OrdMap        1.04 K      962.73 μs    ±11.38%      931.25 μs     1343.39 μs

    Comparison:
    Map                 5.24 K
    A.OrdMap        1.04 K - 5.04x slower +771.78 μs

    ##### With input n = 100000 #####
    Name                   ips        average  deviation         median         99th %
    Map                  20.81       48.05 ms     ±5.96%       48.00 ms       56.58 ms
    A.OrdMap          5.29      189.15 ms     ±6.43%      187.72 ms      218.53 ms

    Comparison:
    Map                  20.81
    A.OrdMap          5.29 - 3.94x slower +141.10 ms
  """

  def insert_all_fun(empty_map, insert_fun) do
    fn n ->
      Enum.reduce(1..n, empty_map, fn i, acc -> insert_fun.(acc, i, i) end)
    end
  end

  def inputs() do
    for n <- [10, 1000, 100_000], do: {"n = #{n}", n}
  end

  def run() do
    Benchee.run(
      [
        {"Map", insert_all_fun(%{}, &Map.put/3)},
        {"A.OrdMap", insert_all_fun(A.OrdMap.new(), &A.OrdMap.put/3)}
      ],
      inputs: inputs()
    )
  end
end

Bench.OrdMap.Put.run()
