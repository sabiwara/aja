list = Enum.to_list(1..20)
queue = Queue.new(list)
simple_queue = SimpleQueue.new(list)
peekable_queue = PeekableQueue.new(list)
raw_queue = :queue.from_list(list)

Benchee.run(%{
  "Queue" => fn -> Queue.delete_first(queue) end,
  "SimpleQueue" => fn -> SimpleQueue.delete_first(simple_queue) end,
  "PeekableQueue" => fn -> PeekableQueue.delete_first(peekable_queue) end,
  ":queue" => fn -> :queue.drop(raw_queue) end
})
