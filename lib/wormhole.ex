defmodule Wormhole do
  use Application

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
  Default timeout is #{@timeout_ms} milliseconds.
  User can specify `timeout_ms` in `options` keyword list.

  By default there is no retry, but user can specify
  `retry_count` and `backoff_ms` in `options`.
  Default `backoff_ms` is #{@backoff_ms} milliseconds.
  """

  @doc """
  #{@description}

  Examples:
      iex> capture(fn-> :a end)
      {:ok, :a}

      iex> capture(fn-> raise "Something happened" end) |> elem(0)
      :error

      iex> capture(fn-> throw "Something happened" end) |> elem(0)
      :error

      iex> capture(fn-> exit :foo end)
      {:error, :foo}

      iex> capture(fn-> Process.exit(self, :foo) end)
      {:error, :foo}

      iex> capture(fn-> :timer.sleep 20 end, timeout_ms: 50)
      {:ok, :ok}

      iex> capture(fn-> :timer.sleep :infinity end, timeout_ms: 50)
      {:error, {:timeout, 50}}

      iex> capture(fn-> exit :foo end, [retry_count: 3, backoff_ms: 100])
      {:error, :foo}
  """
  def capture(callback, options \\ [])
  def capture(callback, options) do
    Wormhole.Capture.capture(callback, options)
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
  """
  def capture(module, function, args, options \\ [])
  def capture(module, function, args, options) do
    Wormhole.Capture.capture(module, function, args, options)
  end
end

