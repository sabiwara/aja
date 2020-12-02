# TODO bench bigger numbers
list = Enum.to_list(1..100)
vector = Vector.new(list)

Benchee.run(%{
  "Vector.reverse/1" => fn -> Vector.reverse(vector) end,
  "Enum.reverse/2" => fn -> Enum.reverse(list) end
})
