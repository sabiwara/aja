list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.with_index/1" => fn -> Aja.Vector.with_index(vector) end,
  "Enum.with_index/1" => fn -> Enum.with_index(list) end
})
