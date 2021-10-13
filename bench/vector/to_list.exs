# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = Aja.Vector.new(list)

Benchee.run(%{
  ":array.to_list/1 (array)" => fn -> :array.to_list(array) end,
  "Aja.Vector.to_list/1 (vector)" => fn -> Aja.Vector.to_list(vector) end,
  "Aja.Enum.to_list/1 (vector)" => fn -> Aja.Enum.to_list(vector) end,
  "Enum.to_list/1 (vector)" => fn -> Enum.to_list(vector) end
})
