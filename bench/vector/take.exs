list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.take/2" => fn -> Aja.Vector.take(vector, 80) end,
  "Aja.Vector.slice/3" => fn -> Aja.Vector.slice(vector, 1, 80) end,
  "Aja.Vector.slice/3 0-optimization" => fn -> Aja.Vector.slice(vector, 0, 80) end,
  "Enum.take/2 (list)" => fn -> Enum.take(list, 80) end
})
