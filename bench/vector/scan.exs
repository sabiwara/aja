list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.scan/2" => fn -> Aja.Vector.scan(vector, &+/2) end,
  "Aja.Vector.scan/3" => fn -> Aja.Vector.scan(vector, 0, &+/2) end,
  "Enum.scan/2" => fn -> Enum.scan(list, &+/2) end,
  "Enum.scan/3" => fn -> Enum.scan(list, 0, &+/2) end
})
