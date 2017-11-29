defmodule TwitterEngine.Simulator do
  @moduledoc """
  Simulator to test the functionality of the twitter engine using a population
  that exhibits preferential attachment for most attributes, causing a ZIPF
  distribution to form. This applies to any activity that is triggered by the
  user
  """

  use GenServer

  alias TwitterEngine.Simulator.UserProcess

  require Logger

  def start_link(%{user_count: uc}) do
    {:ok, pid} = GenServer.start_link(__MODULE__, %{user_count: uc}, name: __MODULE__)
    pid
  end

  def setup_users(:zipf) do
    # TODO: Possibly assign a large timeout to setup the network graph
    GenServer.call(__MODULE__, {:setup_users, :zipf})
  end

  def simulate do
    GenServer.cast(__MODULE__, :simulate)
  end

  def init(%{user_count: n}) do
    state = { 1..n |> Enum.map(fn _ -> UserProcess.start_link end)}
    {:ok, state}
  end

  def handle_call({:setup_users, :zipf}, _from, state) do
    # TODO: The returned state should represent connected users as follows:
    # 1. Create a Zipf distribution of followers
    # 2. Assign an affinity to each user for creating tweets
    #    based on their rank in the system
    {:reply, state}
  end

  def handle_cast(:simulate, state) do
    # TODO:
    # 1. Create a process for each user on the system
    # 2. Once process creation is done, signal all of the processes to start
    #     working

    {:noreply, state}
  end
end
