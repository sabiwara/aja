list = Enum.to_list(1..50) ++ Enum.to_list(50..1)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.dedup/1 (vector)" => fn -> Aja.Vector.dedup(vector) end,
  "Aja.Enum.dedup/1 (vector)" => fn -> Aja.Enum.dedup(vector) end,
  "Aja.Enum.dedup/2 (list)" => fn -> Aja.Enum.dedup(list) end,
  "Enum.dedup/2 (list)" => fn -> Enum.dedup(list) end
})
