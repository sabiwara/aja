list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Enum.count/1 (list)" => fn -> Enum.count(list) end,
  "Enum.count/1 (vector)" => fn -> Enum.count(vector) end,
  "Aja.Enum.count/1 (vector)" => fn -> Aja.Enum.count(vector) end
})
