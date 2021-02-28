# TODO bench bigger numbers
list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.filter/2 (vector)" => fn -> A.Vector.filter(vector, &(rem(&1, 2) == 0)) end,
  "A.Enum.filter/2 (vector)" => fn -> A.Enum.filter(vector, &(rem(&1, 2) == 0)) end,
  "Enum.filter/2 (list)" => fn -> Enum.filter(list, &(rem(&1, 2) == 0)) end
})
