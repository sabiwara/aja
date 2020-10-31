defmodule Bench.RBSet.New do
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
        {"MapSet", &MapSet.new/1},
        {"A.RBSet", &A.RBSet.new/1},
        # {":gb_sets (unsafe/broken)", &:gb_sets.from_ordset/1},
        {":gb_sets (safe)",
         fn values ->
           Enum.reduce(values, :gb_sets.empty(), fn val, acc ->
             :gb_sets.add_element(val, acc)
           end)
         end}
      ],
      inputs: inputs(),
      before_scenario: fn n ->
        :rand.seed(:exsplus, {1, 2, 3})
        1..n |> shuffle() |> Enum.to_list()
      end
    )
  end
end

Bench.RBSet.New.run()
