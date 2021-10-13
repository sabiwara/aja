inputs =
  Enum.map([100, 101, 1_000, 1_001, 10_000, 10_001], fn n ->
    {"n = #{n}", n}
  end)

Benchee.run(
  %{
    ":array.set/3" =>
      {fn {array, i} -> :array.set(i, :foo, array) end,
       before_scenario: fn n ->
         {1..n |> Enum.to_list() |> :array.from_list(), div(n, 2)}
       end},
    "Aja.Vector.replace_at/3" =>
      {fn {vector, i} -> Aja.Vector.replace_at(vector, i, :foo) end,
       before_scenario: fn n -> {Aja.Vector.new(1..n), div(n, 2)} end},
    "List.replace_at/3" =>
      {fn {list, i} -> List.replace_at(list, i, :foo) end,
       before_scenario: fn n -> {Enum.to_list(1..n), div(n, 2)} end}
  },
  inputs: inputs,
  time: 2
)
