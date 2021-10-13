list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.join/2 (vector)" => fn -> Aja.Enum.join(vector, ",") end,
  "Enum.join/2 (list)" => fn -> Enum.join(list, ",") end
})
