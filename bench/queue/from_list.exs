list = Enum.to_list(1..20)

Benchee.run(%{
  "Queue" => fn -> Queue.new(list) end,
  ":queue" => fn -> :queue.from_list(list) end
})
