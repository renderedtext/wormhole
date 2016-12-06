defmodule Wormhole.Defaults do
  def timeout_ms,  do: 5_000
  def retry_count, do: 1
  def backoff_ms,  do: 1_000
end
