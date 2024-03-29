defmodule KafkaMessageBus.Adapters.Exq do
  alias KafkaMessageBus.{
    Config,
    Adapter,
    Adapters.Exq.Consumer
  }

  require Logger

  @behaviour Adapter

  @impl Adapter
  def init(config) do
    Logger.info(fn ->
      "Initializing Exq adapter"
    end)

    config
    |> to_exq_config()
    |> apply_exq_config()

    Logger.debug(fn ->
      "Exq configuration applied"
    end)

    start_exq()
  end

  @impl Adapter
  def produce(message, opts) do
    topic = Keyword.get(opts, :topic, Config.default_topic())
    resource = message.resource

    message = Poison.encode!(message)

    :exq
    |> Application.get_env(:consumers)
    |> Enum.flat_map(fn
      {^topic, ^resource, module} ->
        [module]

      _ ->
        []
    end)
    |> case do
      [] ->
        {:error, :no_consumers}

      modules ->
        Enum.each(modules, fn module ->
          Exq.enqueue(Exq, topic, Consumer, [module, message])
        end)
    end
  end

  defp to_exq_config(config) do
    [{host, port} | _] = config[:endpoints]

    queues =
      Enum.map(config[:consumers], fn entry ->
        entry
        |> Tuple.to_list()
        |> List.first()
      end)

    [
      concurrency: 600,
      host: Atom.to_string(host),
      max_retries: 100,
      name: Exq,
      namespace: config[:namespace],
      poll_timeout: 50,
      port: port,
      queues: queues,
      scheduler_enable: true,
      scheduler_poll_timeout: 200,
      shutdown_timeout: 5000,
      start_on_application: false,
      consumers: config[:consumers]
    ]
  end

  defp apply_exq_config(config) do
    Enum.each(config, fn {key, value} ->
      Application.put_env(:exq, key, value)
    end)
  end

  defp start_exq do
    import Supervisor.Spec

    {:ok, _} = Application.ensure_all_started(:exq)

    {:ok, worker(Exq, [])}
  end
end
