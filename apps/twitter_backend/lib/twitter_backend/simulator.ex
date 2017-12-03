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

  def start_link(%{user_count: uc, nchar: nchar}) do
    {:ok, pid} = GenServer.start_link(
      __MODULE__,
      %{user_count: uc, nchar: nchar},
      name: __MODULE__)

    pid
  end

  def setup_users(:zipf) do
    # TODO: Possibly assign a large timeout to setup the network graph
    GenServer.call(__MODULE__, {:setup_users, :zipf}, :infinity)
  end

  def start_simulation do
    GenServer.cast(__MODULE__, :simulate)
  end

  def print_metrics({prev_count, then_time}) do
    {curr_count, now_time} = TwitterEngine.CoreApi.get_metrics()

    num_tweets = curr_count - prev_count
    interval = :timer.now_diff(now_time, then_time)

    tweet_rate = if interval > 0 do
      1.0e+6 * (num_tweets / interval)
    else
      0
    end

    Logger.info "Tweets / s: #{tweet_rate}"

    # Don't bombard the server
    :timer.sleep(1000)

    print_metrics({curr_count, now_time})
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
    Logger.info "Initializing #{n} distinct processes for each user"

    state = 1..n |>
      Enum.map(fn _ -> UserProcess.start_link end)

    Logger.debug "UserProcess list: #{inspect state}"

    {:ok, state}
  end

  def handle_call({:setup_users, :zipf}, _from, state) do
    Logger.info "Linking users into a follower graph"

    user_procs = state
    link_users(user_procs)

    Logger.info "Completed linkage"
    {:reply, nil, state}
  end

  def handle_cast(:simulate, state) do
    # Simulate only fires up the user processes

    user_procs = state
    user_procs
    |> Enum.each(
      fn u ->
        UserProcess.chatter(u, 10 |>:crypto.strong_rand_bytes |> Base.encode16)
      end)
    {:noreply, state}
  end
end
