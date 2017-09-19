defmodule KafkaMessageBus.MessageProcessor.Behaviour do
  @type data :: Map.t
  @type key :: String.t
  @type action :: String.t
  @type resource :: String.t

  @callback process(data, key, action, resource) :: :ok
end
