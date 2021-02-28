list = Enum.to_list(1..100)
vector = A.Vector.new(list)

fun = fn x -> x <= 80 end

Benchee.run(%{
  "A.Vector.take_while/2" => fn -> A.Vector.take_while(vector, fun) end,
  "Enum.take_while/2 (list)" => fn -> Enum.take_while(list, fun) end
})
