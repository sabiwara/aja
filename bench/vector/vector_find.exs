last = 1000
list = Enum.to_list(1..last)
fun = fn i -> i == last end
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.fun/2 (list)" => fn -> Enum.find(list, fun) end,
  "A.Vector.fun/2" => fn -> A.Vector.find(vector, fun) end,
  "Enum.fun/2 (vector)" => fn -> Enum.find(vector, fun) end
})
