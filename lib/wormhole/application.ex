defmodule Wormhole.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Task.Supervisor, [[name: :wormhole_task_supervisor]]),
    ]

    opts = [strategy: :one_for_one, name: Wormhole.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
