# TODO bench bigger numbers
list = Enum.to_list(1..1000)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.sum/1 (vector)" => fn -> Aja.Enum.sum(vector) end,
  "Enum.sum/1 (vector)" => fn -> Enum.sum(vector) end,
  "Aja.Enum.reduce/3 (vector)" => fn -> Aja.Enum.reduce(vector, 0, &+/2) end,
  "Enum.sum/1 (list)" => fn -> Enum.sum(list) end,
  ":lists.sum/1" => fn -> :lists.sum(list) end
})
