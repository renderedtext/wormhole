defmodule Wormhole.CallbackWrapper do

  @doc """
  Prevent callback from generating crush report.
  """
  def wrap(callback) do
    fn ->
      try do
        response = callback.()

        # Do not send response to the caller if it timed-out
        receive do
          {:wormhole_timeout, :silence} ->
            exit {:shutdown, :wormhole_timeout}
          after 0 ->
            response
        end
      catch _key, error ->
        exit {:shutdown, error}
      end
    end
  end

end
