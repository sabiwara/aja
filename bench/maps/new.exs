defmodule Bench.Maps.New do
  @shuffled true

  def inputs() do
    for n <- [10, 100, 10_000], do: {"n = #{n}", n}
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
        {"Map", &Map.new/1},
        {"A.OrdMap", &A.OrdMap.new/1},
        {"A.RBMap", &A.RBMap.new/1},
        # {":gb_trees (unsafe/broken)", &:gb_trees.from_orddict/1},
        {":gb_trees (safe)",
         fn kvs ->
           Enum.reduce(kvs, :gb_trees.empty(), fn {k, v}, acc ->
             :gb_trees.enter(k, v, acc)
           end)
         end}
      ],
      inputs: inputs(),
      before_scenario: fn n ->
        :rand.seed(:exsplus, {1, 2, 3})
        1..n |> shuffle() |> Enum.map(fn i -> {i, "i"} end)
      end
    )
  end
end

Bench.Maps.New.run()
