# TODO bench bigger numbers
list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.reverse/1" => fn -> A.Vector.reverse(vector) end,
  "Enum.reverse/2" => fn -> Enum.reverse(list) end
})
