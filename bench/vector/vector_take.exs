list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.take/2" => fn -> A.Vector.take(vector, 80) end,
  "A.Vector.slice/3" => fn -> A.Vector.slice(vector, 1, 80) end,
  "A.Vector.slice/3 0-optimization" => fn -> A.Vector.slice(vector, 0, 80) end,
  "Enum.take/2 (list)" => fn -> Enum.take(list, 80) end
})
