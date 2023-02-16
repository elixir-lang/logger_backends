defmodule LoggerBackends.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    start_options = Application.fetch_env!(:logger, :start_options)
    counter = :counters.new(1, [:atomics])

    children = [
      %{
        id: :gen_event,
        start: {:gen_event, :start_link, [{:local, LoggerBackends}, start_options]},
        modules: :dynamic
      },
      {LoggerBackends.Watcher, {LoggerBackends.Config, counter}},
      LoggerBackends.Supervisor
    ]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :rest_for_one) do
      :ok =
        :logger.add_handler(LoggerBackends, LoggerBackends.Handler, %{
          level: :all,
          config: %{counter: counter},
          filter_default: :log,
          filters: []
        })

      {:ok, pid}
    end
  end

  @impl true
  def stop(_) do
    _ = :logger.remove_handler(LoggerBackends)
  end
end
