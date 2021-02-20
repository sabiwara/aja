list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.slice/3 (vector)" => fn -> A.Vector.slice(vector, 10, 80) end,
  "Enum.slice/3 (vector)" => fn -> Enum.slice(vector, 10, 80) end,
  "Enum.slice/3 (list)" => fn -> Enum.slice(list, 10, 80) end
})
