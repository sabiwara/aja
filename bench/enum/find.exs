last = 1000
list = Enum.to_list(1..last)
fun = fn i -> i == last end
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.find/2 (list)" => fn -> Enum.find(list, fun) end,
  "A.Enum.find/2 (vector)" => fn -> A.Enum.find(vector, fun) end,
  "Enum.find/2 (vector)" => fn -> Enum.find(vector, fun) end
})
