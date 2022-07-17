list = Enum.to_list(1..20)
queue = Queue.new(list)
raw_queue = :queue.from_list(list)

Benchee.run(%{
  "Queue" => fn -> Queue.delete_first(queue) end,
  ":queue" => fn -> :queue.drop(raw_queue) end
})
