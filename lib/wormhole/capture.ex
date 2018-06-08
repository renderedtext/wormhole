defmodule Wormhole.Capture do
  @moduledoc """
  Caller ------> Terminator <=====> Callback
    ^                                  |
     \                                 |
      ---------------------------------

  Caller process is monitoring Callback proces.
  In case of Callback cresh, DOWN message contains reason (return value).

  Terminator process is monitoring Caller proces and is linked with Callback.
  If Caller crashes, Terminator calls exits(:normal) and stops execution
  of Callback proces.
  """
  require Logger

  alias Wormhole.Defaults


  def exec(callback, options) do
    capture(callback, options)
  end


  defp capture(callback, options) do
    # `timeout_ms` option is deprecated in favor of `timeout`
    timeout_ms   = Keyword.get(options, :timeout_ms)   || Defaults.timeout
    timeout      = Keyword.get(options, :timeout)      || timeout_ms
    crush_report = Keyword.get(options, :crush_report) || Defaults.crush_report
    stacktrace?  = Keyword.get(options, :stacktrace)   || Defaults.stacktrace

    {callback_pid, callback_ref} =
      callback
      |> Wormhole.CallbackWrapper.wrap(self(), crush_report, stacktrace?)
      |> spawn_monitor()

    spawn(__MODULE__, :terminator_fn, [self(), callback_pid])

    wait_for_response(callback_pid, callback_ref, timeout)
  end

  def terminator_fn(caller_pid, callback_pid) do
    caller_ref = Process.monitor(caller_pid)
    try do
      Process.link(callback_pid)
    catch
      _, _ -> exit(:shutdown)
    end

    receive do
      # If caller is DOWN
      {:DOWN, ^caller_ref, :process, ^caller_pid, _reason} ->
        # Exit and terminate callback process
        exit(:shutdown)
    end
  end

  defp wait_for_response(callback_pid, callback_ref, timeout) do
    receive do
      {:wormhole, ^callback_pid, state} ->
        Process.demonitor(callback_ref, [:flush])
        {:ok, state}
      {:DOWN, ^callback_ref, :process, ^callback_pid, reason} ->
        {:error, reason}
    after
      timeout ->
        Process.demonitor(callback_ref, [:flush])
        Process.exit(callback_pid, :shutdown)
        {:error, {:timeout, timeout}}
    end
  end
end
