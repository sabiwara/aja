defmodule Bench.Quick.PutRBMap do
  def inputs() do
    for n <- [30] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, put_callback) do
    {
      fn {map, keys} ->
        Enum.reduce(keys, map, fn key, acc -> put_callback.(acc, key, :foo) end)
      end,
      before_scenario: fn n ->
        map = 1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
        # use several keys to be more representative
        keys = [0, n + 1, n * 2]
        {map, keys}
      end
    }
  end

  def run() do
    Benchee.run(
      [
        {"A.RBMap",
         create_scenario(&A.RBMap.new/1, fn map, key, value -> A.RBMap.put(map, key, value) end)},
        {":gb_trees",
         create_scenario(&:gb_trees.from_orddict/1, fn tree, key, value ->
           :gb_trees.enter(key, value, tree)
         end)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Quick.PutRBMap.run()
