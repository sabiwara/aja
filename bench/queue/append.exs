list = Enum.to_list(1..20)
queue = Queue.new(list)
raw_queue = :queue.from_list(list)

Benchee.run(
  %{
    "Queue" => fn -> Queue.append(queue, :foo) end,
    ":queue" => fn -> :queue.in(:foo, raw_queue) end
  },
  memory_time: 1
)
