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

  def get_user(pid) do
    GenServer.call(pid, :get_user)
  end

  def follow(follower_pid, target_pid) do
    GenServer.cast(follower_pid, {:follow, target_pid})
  end

  def get_followers(pid) do
    GenServer.call(pid, :get_followers)
  end

  ##
  # Server API
  ##
  def init([uhandle]) do
    # Create a user on the server and return the state
    # pid = GenServer.whereis({:global, TwitterEngine.CoreApi})
    TwitterEngine.CoreApi.insert_user(%User{handle: uhandle})
    {:ok, TwitterEngine.CoreApi.get_user_by_handle(uhandle)}
  end

  def handle_call(:get_user, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_followers, _from, state) do
    {:reply, TwitterEngine.CoreApi.get_followers(state.id), state}
  end

  def handle_cast({:follow, target_pid}, state) do
    %User{id: target_id} = get_user(target_pid)
    %User{id: follower_id} = state

    TwitterEngine.CoreApi.add_follower(target_id, follower_id)

    {:noreply, state}
  end
end
