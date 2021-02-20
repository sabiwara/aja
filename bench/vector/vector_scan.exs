list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.scan/2" => fn -> A.Vector.scan(vector, &+/2) end,
  "A.Vector.scan/3" => fn -> A.Vector.scan(vector, 0, &+/2) end,
  "Enum.scan/2" => fn -> Enum.scan(list, &+/2) end,
  "Enum.scan/3" => fn -> Enum.scan(list, 0, &+/2) end
})
