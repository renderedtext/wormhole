defmodule ReliableErrorHandler do
  require Logger

  @timeout_ms 3_000

  @doc """
  Examples:
      iex> r = handle(fn-> raise "Error" end)
      iex> r |> elem(0)
      :error

      iex> r = handle(fn-> throw "Error" end)
      iex> r |> elem(0)
      :error
      iex> r |> elem(1) |> elem(0)
      {:nocatch, "Error"}
  """
  def handle(callback), do:
    handle(callback, @timeout_ms)

  def handle(callback, timeout) do
    {pid, monitor} = spawn_monitor(send_ret_val(callback))
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        IO.puts "ok";
        receive do
          response ->
            IO.puts "Response: #{inspect response}"
            {:ok, response}
        after timeout -> IO.puts "Weird..."
        end
      {:DOWN, ^monitor, :process, ^pid, reason}  ->
        Logger.error "Error in handeled function: #{inspect reason}";
        {:error, reason}
    after timeout ->
      Logger.error "Timeout..."
      {:error, :timeout}
    end

    # IO.puts "Continuing with my life..."
  end

  def handle(module, function, args), do:
    handle(module, function, args, @timeout_ms)

  def handle(module, function, args, timeout) do
    handle(fn-> apply(module, function, args) end, timeout)
  end

  defp send_ret_val(callback) do
    caller_pid = self
    fn-> send(caller_pid, callback.()) end
  end

end
