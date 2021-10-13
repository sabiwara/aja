list = Enum.to_list(1..10_000)
array = :array.from_list(list)
vector = Aja.Vector.new(list)

Benchee.run(%{
  ":array.foldl/3" => fn -> :array.foldl(fn _i, x, acc -> [x | acc] end, [], array) end,
  "Aja.Vector.foldl3" => fn -> Aja.Vector.foldl(vector, [], fn x, acc -> [x | acc] end) end,
  "List.foldl3/2" => fn -> List.foldl(list, [], fn x, acc -> [x | acc] end) end
})
