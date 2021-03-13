list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Enum.join/2 (vector)" => fn -> A.Enum.join(vector, ",") end,
  "Enum.join/2 (list)" => fn -> Enum.join(list, ",") end
})
