list = Enum.to_list(1..50) ++ Enum.to_list(50..1//-1)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.uniq/1 (vector)" => fn -> Aja.Vector.uniq(vector) end,
  "Aja.Enum.uniq/1 (vector)" => fn -> Aja.Enum.uniq(vector) end,
  "Enum.uniq/2 (list)" => fn -> Enum.uniq(list) end
})
