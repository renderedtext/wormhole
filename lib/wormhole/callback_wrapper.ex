defmodule Wormhole.CallbackWrapper do

  @doc """
  Prevent callback from generating crush report.
  """
  def wrap(callback, crush_report) do
    fn -> callback |> catch_errors(crush_report) end
  end


  defp catch_errors(callback, _crush_report=true) do
    callback.() |> scilence_task
  end
  defp catch_errors(callback, _crush_report=false) do
    try do
      callback.() |> scilence_task
    rescue error ->
      exit {:shutdown, error}
    catch key, error ->
      exit {:shutdown, {key, error}}
    end
  end

  defp scilence_task(response) do
    # Do not send response to the caller if it already timed-out
    receive do
      {:wormhole_timeout, :silence} ->
        exit {:shutdown, :wormhole_timeout}
      after 0 ->
        response
    end
  end
end
