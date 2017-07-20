defmodule Wormhole do
  use Application

  alias Wormhole.Defaults

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Task.Supervisor, [[name: :wormhole_task_supervisor]]),
    ]

    opts = [strategy: :one_for_one, name: Wormhole.Supervisor]
    Supervisor.start_link(children, opts)
  end


  #################  API  #################

  @description """
  Invokes `callback` in separate process and
  waits for message from callback process containing callback return value
  if finished successfully or
  error reason if callback process failed for any reason.

  If `callback` execution is not finished within specified timeout,
  kills `callback` process and returns error.
  Default timeout is #{Defaults.timeout_ms} milliseconds.
  User can specify `timeout_ms` in `options` keyword list.

  By default there is no retry, but user can specify
  `retry_count` and `backoff_ms` in `options`.
  Default `backoff_ms` is #{Defaults.backoff_ms} milliseconds.

  By default exceptions in callback-process are handled so that
  supervisor does not generate CRUSH REPORT (when released - Exrm/Distillery).
  This behavior can be overridden by setting `crush_report` to `true`.
  Note:
    - Crush report is not generated in Elixir by default.
    - Letting exceptions propagate might be useful for
      some other applications too (e.g sentry client).
  """

  @doc """
  #{@description}

  Examples:
      iex> capture(fn-> :a end)
      {:ok, :a}

      iex> capture(fn-> raise "Something happened" end)
      {:error, {:shutdown, %RuntimeError{message: "Something happened"}}}

      iex> capture(fn-> throw "Something happened" end)
      {:error, {:shutdown, {:throw, "Something happened"}}}

      iex> capture(fn-> exit :foo end)
      {:error, {:shutdown, {:exit, :foo}}}

      iex> capture(fn-> Process.exit(self, :foo) end)
      {:error, :foo}

      iex> capture(fn-> :timer.sleep 20 end, timeout_ms: 50)
      {:ok, :ok}

      iex> capture(fn-> :timer.sleep :infinity end, timeout_ms: 50)
      {:error, {:timeout, 50}}

      iex> capture(fn-> exit :foo end, [retry_count: 3, backoff_ms: 100])
      {:error, {:shutdown, {:exit, :foo}}}
  """
  def capture(callback, options \\ [])
  def capture(callback, options) do
    Wormhole.Retry.exec(callback, options)
    |> logger(callback)
  end


  @doc """
  #{@description}

  Examples:
      iex> capture(Enum, :count, [[]])
      {:ok, 0}

      iex> capture(Enum, :count, [:foo]) |> elem(0)
      :error

      iex> capture(:timer, :sleep, [20], timeout_ms: 50)
      {:ok, :ok}

      iex> capture(:timer, :sleep, [:infinity], timeout_ms: 50)
      {:error, {:timeout, 50}}

    iex> capture(Kernel, :exit, [:foos], [retry_count: 3, backoff_ms: 100])
    {:error, {:shutdown, {:exit, :foos}}}
  """
  def capture(module, function, args, options \\ [])
  def capture(module, function, args, options) do
    Wormhole.Retry.exec(fn-> apply(module, function, args) end, options)
    |> logger({module, function, args})
  end


  defp logger(response = {:ok, _},         _callback), do: response
  defp logger(response = {:error, reason}, callback)   do
    require Logger
    Logger.warn "#{__MODULE__}{#{inspect self()}}:: callback: #{inspect callback}; reason: #{inspect reason}";

    response
  end
end
