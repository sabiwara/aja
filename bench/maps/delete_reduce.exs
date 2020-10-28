defmodule Bench.Maps.DeleteReduce do
  def inputs() do
    for n <- [10, 100, 10_000] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, delete_callback) do
    {
      fn {map, keys} -> Enum.reduce(keys, map, fn key, acc -> delete_callback.(acc, key) end) end,
      before_scenario: fn n ->
        map = 1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
        :rand.seed(:exsplus, {1, 2, 3})
        keys = 1..n |> Enum.shuffle()
        {map, keys}
      end
    }
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(&Map.new/1, fn map, key -> Map.delete(map, key) end)},
        {"A.OrdMap",
         create_scenario(&A.OrdMap.new/1, fn map, key -> A.OrdMap.delete(map, key) end)},
        {"A.RBMap", create_scenario(&A.RBMap.new/1, fn map, key -> A.RBMap.delete(map, key) end)},
        {"A.RBTree",
         create_scenario(&A.RBTree.map_new/1, fn map, key ->
           {ok, _, tree} = A.RBTree.map_pop(map, key)
           tree
         end)},
        {":gb_trees",
         create_scenario(&:gb_trees.from_orddict/1, fn tree, key ->
           :gb_trees.delete_any(key, tree)
         end)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Maps.DeleteReduce.run()
