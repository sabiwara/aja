list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.map/2 (vector)" => fn -> Aja.Enum.map(vector, &(&1 + 1)) end,
  "Aja.Enum.each/2 (vector)" => fn -> Aja.Enum.each(vector, &(&1 + 1)) end,
  "Enum.map/2 (list)" => fn -> Enum.map(list, &(&1 + 1)) end,
  "Enum.each/2 (list)" => fn -> Enum.each(list, &(&1 + 1)) end
})
