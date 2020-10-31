defmodule Bench.Maps.ToList do
  def inputs() do
    for n <- [10, 100, 10_000] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, to_list_callback) do
    {
      fn map -> to_list_callback.(map) end,
      before_scenario: fn n ->
        1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
      end
    }
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(&Map.new/1, &Map.to_list/1)},
        {"A.OrdMap", create_scenario(&A.OrdMap.new/1, &A.OrdMap.to_list/1)},
        {"A.RBMap", create_scenario(&A.RBMap.new/1, &A.RBMap.to_list/1)},
        {":gb_trees", create_scenario(&:gb_trees.from_orddict/1, &:gb_trees.to_list/1)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Maps.ToList.run()
