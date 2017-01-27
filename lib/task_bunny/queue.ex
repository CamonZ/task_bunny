defmodule TaskBunny.Queue do
  def declare_with_retry(connection, queue_name, options) do
    {:ok, channel} = AMQP.Channel.open(connection)

    retry_queue = retry_queue_name(queue_name)
    rejected_queue = rejected_queue_name(queue_name)

    retry_interval = options[:retry_interval] || 60_000

    # Send dead lettered message to retry queue
    main_options = [
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, retry_queue}
      ],
      durable: true
    ]
    work = declare(channel, queue_name, main_options)

    # Set main queue as dead letter exchange of retry queue.
    # It will requeue the message once message TTL is over.
    retry_options = [
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, queue_name},
        {"x-message-ttl", :long, retry_interval}
      ],
      durable: true
    ]
    retry = declare(channel, retry_queue, retry_options)

    rejected = declare(channel, rejected_queue, [durable: true])

    AMQP.Channel.close(channel)

    {work, retry, rejected}
  end

  def delete_with_retry(connection, queue_name) do
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.delete(channel, queue_name)
    AMQP.Queue.delete(channel, retry_queue_name(queue_name))
    AMQP.Queue.delete(channel, rejected_queue_name(queue_name))

    AMQP.Channel.close(channel)
    :ok
  end

  def declare(channel, queue_name, options \\ []) do
    options = options ++ [durable: true]
    {:ok, state} = AMQP.Queue.declare(channel, queue_name, options)

    state
  end

  def state(connection, queue) do
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, state} = AMQP.Queue.status(channel, queue)
    AMQP.Channel.close(channel)

    state
  end

  def retry_queue_name(queue_name) do
    queue_name <> ".retry"
  end

  def rejected_queue_name(queue_name) do
    queue_name <> ".rejected"
  end
end
