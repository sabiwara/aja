defmodule Bench.Maps.PutExisting do
  def inputs() do
    for n <- [10, 100, 10_000] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, put_callback) do
    {
      fn {map, keys} -> Enum.each(keys, fn key -> put_callback.(map, key, :foo) end) end,
      before_scenario: fn n ->
        map = 1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
        # use several keys to be more representative
        keys = sample_keys(n, 3) ++ sample_keys(n, 4)
        {map, keys}
      end
    }
  end

  defp sample_keys(n, p) do
    1..(p - 1) |> Enum.map(fn i -> div(i * n, p) end)
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(&Map.new/1, fn map, key, value -> Map.put(map, key, value) end)},
        {"A.OrdMap",
         create_scenario(&A.OrdMap.new/1, fn map, key, value -> A.OrdMap.put(map, key, value) end)},
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

Bench.Maps.PutExisting.run()
