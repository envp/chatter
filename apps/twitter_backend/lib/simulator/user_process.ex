defmodule TwitterEngine.Simulator.UserProcess do
  @moduledoc """
  Represents a single user within the simulator. Each user is treated as a
  distinct actor
  """

  use GenServer

  alias TwitterEngine.User

  require Logger

  ##
  # Client API
  ##
  def start_link do
    uhandle = :crypto.strong_rand_bytes(10) |> Base.encode16
    start_link(%{handle: uhandle})
  end
  def start_link(%{handle: uhandle}) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [uhandle])
    pid
  end

  ##
  # Server API
  ##
  def init([uhandle]) do
    # Create a user on the server and return the state
    # pid = GenServer.whereis({:global, TwitterEngine.CoreApi})
    TwitterEngine.CoreApi.insert_user(%User{handle: uhandle})
    {:ok, uhandle}
  end
end
