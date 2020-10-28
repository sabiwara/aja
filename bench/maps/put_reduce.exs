defmodule Bench.Maps.PutReduce do
  @shuffled true

  def inputs() do
    for n <- [10, 100, 1000, 10_000], do: {"n = #{n}", n}
  end

  def create_scenario(initial, put_callback) do
    {
      fn key_values ->
        Enum.reduce(key_values, initial, fn {key, value}, acc ->
          put_callback.(acc, key, value)
        end)
      end,
      before_scenario: fn n ->
        :rand.seed(:exsplus, {1, 2, 3})
        1..n |> shuffle() |> Enum.map(fn i -> {i, "i"} end)
      end
    }
  end

  defp shuffle(enum) do
    if @shuffled do
      :rand.seed(:exsplus, {1, 2, 3})
      Enum.shuffle(enum)
    else
      enum
    end
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(%{}, fn map, key, value -> Map.put(map, key, value) end)},
        {"A.OrdMap",
         create_scenario(A.OrdMap.new(), fn map, key, value -> A.OrdMap.put(map, key, value) end)},
        {"A.RBMap",
         create_scenario(A.RBMap.new(), fn map, key, value -> A.RBMap.put(map, key, value) end)},
        {"A.RBTree",
         create_scenario(A.RBTree.empty(), fn tree, key, value ->
           {_, tree} = A.RBTree.map_insert(tree, key, value)
           tree
         end)},
        {":gb_trees",
         create_scenario(:gb_trees.empty(), fn tree, key, value ->
           :gb_trees.enter(key, value, tree)
         end)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Maps.PutReduce.run()
