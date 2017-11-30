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

  def start_simulation do
    GenServer.cast(__MODULE__, :simulate)
  end

  defp link_users([h | t]) do
    t
    |> Enum.take_random(4)
    |> Enum.each(fn u -> UserProcess.follow(u, h) end)

    if length(t) > 4, do: link_users(t)
  end

  def init(%{user_count: n}) do
    Logger.debug "Initializing #{n} distinct processes for each user"

    state = 1..n |>
      Enum.map(fn _ -> UserProcess.start_link end)

    {:ok, state}
  end

  def handle_call({:setup_users, :zipf}, _from, state) do
    Logger.debug "Linking users into a follower graph"

    user_procs = state
    link_users(user_procs)

    {:reply, nil, state}
  end

  def handle_cast(:simulate, state) do
    {:noreply, state}
  end
end
