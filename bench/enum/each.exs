list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Enum.map/2 (vector)" => fn -> A.Enum.map(vector, &(&1 + 1)) end,
  "A.Enum.each/2 (vector)" => fn -> A.Enum.each(vector, &(&1 + 1)) end,
  "Enum.map/2 (list)" => fn -> Enum.map(list, &(&1 + 1)) end,
  "Enum.each/2 (list)" => fn -> Enum.each(list, &(&1 + 1)) end
})
