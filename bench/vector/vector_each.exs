list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.map/2" => fn -> A.Vector.map(vector, &(&1 + 1)) end,
  "A.Vector.each/2" => fn -> A.Vector.each(vector, &(&1 + 1)) end,
  "Enum.map/2" => fn -> Enum.map(list, &(&1 + 1)) end,
  "Enum.each/2" => fn -> Enum.each(list, &(&1 + 1)) end
})
