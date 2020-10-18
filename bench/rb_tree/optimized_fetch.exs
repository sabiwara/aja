defmodule Bench.RBTree.OptimizedFetch do
  @moduledoc ~S"""
  Benchmark of optimization X.X from Okasaki's "Purely Functional Data Structures".

  `optimized_fetch` is actually slower than naive `fetch`: even if it reduce the number
  of comparisons, the extra work to pass the candidate around seems to cost more
  and the number of comparisons is O(log n) anyway.
  """

  def optimized_fetch(tree, key), do: do_fetch(tree, key, :none)

  defp do_fetch(:E, _key, :none), do: :error

  defp do_fetch(:E, key, {:candidate, {candidate, _value}}) when candidate < key, do: :error

  defp do_fetch(:E, _key, {:candidate, {_candidate_key, value}}), do: {:ok, value}

  defp do_fetch({_color, left, {tree_key, _value}, _right}, key, candidate) when key < tree_key,
    do: do_fetch(left, key, candidate)

  defp do_fetch({_color, _left, key_value, right}, key, _candidate),
    do: do_fetch(right, key, {:candidate, key_value})

  def tree_of_size(n) do
    key_value = Enum.map(1..n, fn i -> {i, i} end)
    A.RBTree.map_new(key_value)
  end

  def find_all_fun(fetch_fun) do
    fn {n, tree} ->
      Enum.each(1..n, fn i -> fetch_fun.(tree, i) end)
    end
  end

  def inputs() do
    for n <- [10, 1000, 100_000], do: {"n = #{n}", {n, tree_of_size(n)}}
  end

  def run() do
    Benchee.run(
      [
        {"fetch", find_all_fun(&A.RBTree.map_fetch/2)},
        {"fast_fetch", find_all_fun(&optimized_fetch/2)}
      ],
      inputs: inputs()
    )
  end
end

Bench.RBTree.OptimizedFetch.run()

# ##### With input n = 10 #####
# Name                 ips        average  deviation         median         99th %
# fetch             1.13 M        0.89 μs  ±2989.86%        0.78 μs        1.22 μs
# fast_fetch        0.82 M        1.21 μs  ±1848.32%        1.02 μs        2.13 μs

# Comparison:
# fetch             1.13 M
# fast_fetch        0.82 M - 1.37x slower +0.32 μs

# ##### With input n = 1000 #####
# Name                 ips        average  deviation         median         99th %
# fetch             6.92 K      144.51 μs    ±15.56%      141.11 μs      224.16 μs
# fast_fetch        5.16 K      193.64 μs    ±22.30%      181.87 μs      288.54 μs

# Comparison:
# fetch             6.92 K
# fast_fetch        5.16 K - 1.34x slower +49.13 μs

# ##### With input n = 100000 #####
# Name                 ips        average  deviation         median         99th %
# fetch              50.64       19.75 ms     ±4.45%       19.52 ms       24.39 ms
# fast_fetch         38.71       25.84 ms     ±4.76%       25.49 ms       33.82 ms

# Comparison:
# fetch              50.64
# fast_fetch         38.71 - 1.31x slower +6.09 ms
