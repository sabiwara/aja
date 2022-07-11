list = Enum.to_list(1..20)
queue = Queue.new(list)
simple_queue = SimpleQueue.new(list)
peekable_queue = PeekableQueue.new(list)
keyed_queue = KeyedQueue.new(list)
raw_queue = :queue.from_list(list)

Benchee.run(%{
  "Queue" => fn -> Queue.append(queue, :foo) end,
  "SimpleQueue" => fn -> SimpleQueue.append(simple_queue, :foo) end,
  "PeekableQueue" => fn -> PeekableQueue.append(peekable_queue, :foo) end,
  "KeyedQueue" => fn -> KeyedQueue.append(keyed_queue, :foo) end,
  ":queue" => fn -> :queue.in(:foo, raw_queue) end
})
