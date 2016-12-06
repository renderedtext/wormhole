defmodule Wormhole.CallbackWrapper do

  @doc """
  Prevent callback from generating crush report.
  """
  def wrap(callback) do
    fn ->
      try do
        callback.()
      catch _key, error ->
        exit {:shutdown, error}
      end
    end
  end

end
