defmodule LoggerBackendsTest do
  use Logger.Case
  require Logger

  defmodule MyBackend do
    @behaviour :gen_event

    def init({MyBackend, pid}) when is_pid(pid) do
      {:ok, pid}
    end

    def handle_event(event, state) do
      send(state, {:event, event})
      {:ok, state}
    end

    def handle_call(:error, _) do
      raise "oops"
    end

    def handle_info(_msg, state) do
      {:ok, state}
    end

    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end

    def terminate(_reason, _state) do
      :ok
    end
  end

  test "add_backend/1 and remove_backend/1" do
    assert {:ok, _pid} = LoggerBackends.add(LoggerBackends.Console)
    assert LoggerBackends.add(LoggerBackends.Console) == {:error, :already_present}
    assert :ok = LoggerBackends.remove(LoggerBackends.Console)
    assert LoggerBackends.remove(LoggerBackends.Console) == {:error, :not_found}
  end

  test "add_backend/1 with {module, id}" do
    assert {:ok, _} = LoggerBackends.add({MyBackend, self()})
    assert {:error, :already_present} = LoggerBackends.add({MyBackend, self()})
    assert :ok = LoggerBackends.remove({MyBackend, self()})
  end

  test "add_backend/1 with unknown backend" do
    assert {:error, {{:EXIT, {:undef, [_ | _]}}, _}} =
             LoggerBackends.add({UnknownBackend, self()})
  end

  test "logs or writes to stderr on failed call on async mode" do
    assert {:ok, _} = LoggerBackends.add({MyBackend, self()})

    assert capture_log(fn ->
             ExUnit.CaptureIO.capture_io(:stderr, fn ->
               :gen_event.call(LoggerBackends, {MyBackend, self()}, :error)
               wait_for_handler(LoggerBackends, {MyBackend, self()})
             end)
           end) =~
             ~r":gen_event handler {LoggerBackendsTest.MyBackend, #PID<.*>} installed in LoggerBackends terminating"

    Logger.flush()
  after
    LoggerBackends.remove({MyBackend, self()})
  end

  test "logs or writes to stderr on failed call on sync mode" do
    LoggerBackends.configure(sync_threshold: 0)
    assert {:ok, _} = LoggerBackends.add({MyBackend, self()})

    assert capture_log(fn ->
             ExUnit.CaptureIO.capture_io(:stderr, fn ->
               :gen_event.call(LoggerBackends, {MyBackend, self()}, :error)
               wait_for_handler(LoggerBackends, {MyBackend, self()})
             end)
           end) =~
             ~r":gen_event handler {LoggerBackendsTest.MyBackend, #PID<.*>} installed in LoggerBackends terminating"

    Logger.flush()
  after
    LoggerBackends.configure(sync_threshold: 20)
    LoggerBackends.remove({MyBackend, :hello})
  end

  test "logs when discarding messages" do
    assert :ok = LoggerBackends.configure(discard_threshold: 5)
    LoggerBackends.add({MyBackend, self()})

    capture_log(fn ->
      :sys.suspend(LoggerBackends)
      for _ <- 1..10, do: Logger.warning("warning!")
      :sys.resume(LoggerBackends)
      Logger.flush()
      send(LoggerBackends, {LoggerBackends.Config, :update_counter})
    end)

    assert_receive {:event,
                    {:warning, _,
                     {Logger, "Attempted to log 0 messages, which is below :discard_threshold",
                      _time, _metadata}}}
  after
    :sys.resume(LoggerBackends)
    LoggerBackends.remove({MyBackend, self()})
    assert :ok = LoggerBackends.configure(discard_threshold: 500)
  end

  test "restarts LoggerBackends.Config on Logger exits" do
    LoggerBackends.configure([])

    capture_log(fn ->
      Process.whereis(LoggerBackends) |> Process.exit(:kill)
      wait_for_logger()
      wait_for_handler(LoggerBackends, LoggerBackends.Config)
    end)
  end
end
