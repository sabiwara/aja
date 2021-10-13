list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.concat/2 (vector, list)" => fn -> Aja.Vector.concat(vector, list) end,
  "Aja.Enum.concat/2 (vector, list)" => fn -> Aja.Enum.concat(vector, list) end,
  "Enum.concat/2 (vector, list)" => fn -> Enum.concat(vector, list) end,
  "Aja.Enum.concat/2 (vector, vector)" => fn -> Aja.Enum.concat(vector, vector) end,
  "Enum.concat/2 (vector, vector)" => fn -> Enum.concat(vector, vector) end,
  "++/2" => fn -> list ++ list end
})
