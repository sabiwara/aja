list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.concat/2 (vector, list)" => fn -> A.Vector.concat(vector, list) end,
  "A.Enum.concat/2 (vector, list)" => fn -> A.Enum.concat(vector, list) end,
  "Enum.concat/2 (vector, list)" => fn -> Enum.concat(vector, list) end,
  "A.Enum.concat/2 (vector, vector)" => fn -> A.Enum.concat(vector, vector) end,
  "Enum.concat/2 (vector, vector)" => fn -> Enum.concat(vector, vector) end,
  "++/2" => fn -> list ++ list end
})
