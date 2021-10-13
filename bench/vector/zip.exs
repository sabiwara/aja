list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.zip/2" => fn -> Aja.Vector.zip(vector, vector) end,
  "Enum.zip/2" => fn -> Enum.zip(list, list) end,
  "Aja.Enum.zip/2" => fn -> Aja.Enum.zip(list, list) end
})
