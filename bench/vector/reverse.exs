list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.reverse/1 (vector)" => fn -> Aja.Enum.reverse(vector) end,
  "Aja.Vector.reverse/1 (vector)" => fn -> Aja.Vector.reverse(vector) end,
  "Enum.reverse/2 (list)" => fn -> Enum.reverse(list) end
})
