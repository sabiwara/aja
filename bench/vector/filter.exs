# TODO bench bigger numbers
list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.filter/2 (vector)" => fn -> Aja.Vector.filter(vector, &(rem(&1, 2) == 0)) end,
  "Aja.Enum.filter/2 (vector)" => fn -> Aja.Enum.filter(vector, &(rem(&1, 2) == 0)) end,
  "Enum.filter/2 (list)" => fn -> Enum.filter(list, &(rem(&1, 2) == 0)) end,
  "Aja.Enum.filter/2 (list)" => fn -> Aja.Enum.filter(list, &(rem(&1, 2) == 0)) end
})
