list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Enum.reverse/1 (vector)" => fn -> A.Enum.reverse(vector) end,
  "A.Vector.reverse/1 (vector)" => fn -> A.Vector.reverse(vector) end,
  "Enum.reverse/2 (list)" => fn -> Enum.reverse(list) end
})
