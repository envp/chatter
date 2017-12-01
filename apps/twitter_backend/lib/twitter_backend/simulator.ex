defmodule TwitterEngine.Simulator do
  @moduledoc """
  Simulator to test the functionality of the twitter engine using a population
  that exhibits preferential attachment for most attributes, causing a ZIPF
  distribution to form. This applies to any activity that is triggered by the
  user
  """

  use GenServer

  alias TwitterEngine.Simulator.{UserProcess, Zipf}

  require Logger

  def start_link(%{user_count: uc}) do
    {:ok, pid} = GenServer.start_link(__MODULE__, %{user_count: uc}, name: __MODULE__)
    pid
  end

  def setup_users(:zipf) do
    # TODO: Possibly assign a large timeout to setup the network graph
    GenServer.call(__MODULE__, {:setup_users, :zipf}, :infinity)
  end

  def start_simulation do
    GenServer.cast(__MODULE__, :simulate)
    # Process.send_after(self(), :simulate, 1000)
    :timer.sleep(1)
    start_simulation
  end

  defp link_users(user_list) do
    n = length(user_list)

    # Set tweeting affinities
    Zipf.get_probabilities(n, 0.5)
    |> Enum.zip(user_list)
    |> Enum.each(fn {p, u} -> UserProcess.set_affinity(u, p) end)

    # Mass follow to create a power-law distribution of followers
    Zipf.get_probabilities(n, 2)
    |> Zipf.assign_resources(user_list)
    |> Enum.zip(user_list)
    |> Enum.each(fn {follwers, user_pid} ->
      follwers |> Enum.each(
          fn follower ->
            %TwitterEngine.User{id: user_id} = UserProcess.get_user(user_pid)
            UserProcess.follow(follower, user_id)
          end)
      end)
  end

  def init(%{user_count: n}) do
    Logger.debug "Initializing #{n} distinct processes for each user"

    state = 1..n |>
      Enum.map(fn _ -> UserProcess.start_link end)

    Logger.debug "UserProcess list: #{inspect state}"

    {:ok, state}
  end

  def handle_call({:setup_users, :zipf}, _from, state) do
    Logger.debug "Linking users into a follower graph"

    user_procs = state
    link_users(user_procs)

    {:reply, nil, state}
  end

  def handle_cast(:simulate, state) do
    # TODO: Everybody starts talking
    user_procs = state

    user_procs
    |> Enum.each(
      fn u ->
        %{id: id} = UserProcess.get_user(u)
        TwitterEngine.CoreApi.create_tweet(id,
          10 |>:crypto.strong_rand_bytes |> Base.encode16
        )
      end)

    {:noreply, state}
  end

  def handle_info(:simulate, state) do
    user_procs = state

    user_procs
    |> Enum.each(
    fn u ->
      %{id: id} = UserProcess.get_user(u)
      TwitterEngine.CoreApi.create_tweet(id,
        10 |>:crypto.strong_rand_bytes |> Base.encode16
      )
    end)

    {:noreply, state}
  end
end
