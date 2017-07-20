defmodule Wormhole.Retry do
  require Logger

  alias Wormhole.Defaults


  def exec(callback, options) do
    retry(callback, options)
  end


  defp retry(callback, options) do
    (Keyword.get(options, :retry_count) || Defaults.retry_count)
    |> call_capture_initial(callback, options)
  end

  defp call_capture_initial(retry_count=0, _callback, _options) do
    {:error, {:invalid_value, {:retry_count, retry_count}}}
  end
  defp call_capture_initial(retry_count, callback, options) do
    call_capture(retry_count, callback, options, "")
  end

  defp call_capture(_retry_count=0, _callback, _options, prev_response) do
    prev_response
  end
  defp call_capture(retry_count, callback, options, _prev_response) do
    Wormhole.Capture.exec(callback, options)
    |> capture_response(callback, options, retry_count)
  end

  defp capture_response(response={:ok, _}, _, _, _) do response end
  defp capture_response(response, callback, options, retry_count) do
    backoff_ms  = Keyword.get(options, :backoff_ms) || Defaults.backoff_ms
    jitter = Keyword.get(options, :jitter) && Defaults.jitter

    retry_count - 1
    |> backoff(backoff_ms, response, jitter)
    |> call_capture(callback, options, response)
  end

  defp backoff(retry_count, backoff_ms, response, _jitter=nil) do
    backoff(retry_count, backoff_ms, response)
  end
  defp backoff(retry_count, backoff_ms, response, jitter) do
    backoff(retry_count, backoff_ms + jitter, response)
  end

  defp backoff(retry_count=0, _backoff_ms, _response) do retry_count end
  defp backoff(retry_count, backoff_ms, response) do
    Logger.warn "#{__MODULE__}{#{inspect self()}}:: Retries remaining #{retry_count}, reason: #{inspect response}"
    :timer.sleep(backoff_ms)
    retry_count
  end
end
