list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.with_index/1 (list)" => fn -> Aja.Enum.with_index(list) end,
  "Aja.Enum.with_index/1 (vector)" => fn -> Aja.Enum.with_index(vector) end,
  "Enum.with_index/1 (list)" => fn -> Enum.with_index(list) end,
  "Enum.with_index/1 (vector)" => fn -> Enum.with_index(vector) end
})
