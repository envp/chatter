defmodule TwitterEngine.Simulator.UserProcess do
  @moduledoc """
  Represents a single user within the simulator. Each user is treated as a
  distinct actor
  """

  use GenServer

  alias TwitterEngine.User

  require Logger

  # 10 random bytes
  @message_size 30

  ##
  # Client API
  ##
  def start_link do
    uhandle = :crypto.strong_rand_bytes(4) |> Base.encode16
    start_link(%{handle: uhandle})
  end
  def start_link(%{handle: uhandle}) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [uhandle])
    pid
  end

  def get_user(pid) do
    GenServer.call(pid, :get_user)
  end

  def bulk_follow(follower_pid, targets) do
    targets
    |> Enum.each(fn tgt ->
      %User{id: target_id} = get_user(tgt)
      follow(follower_pid, target_id)
    end)
  end

  def follow(follower_pid, target_id) do
    GenServer.cast(follower_pid, {:follow, target_id})
  end

  def get_followers(pid) do
    GenServer.call(pid, :get_followers, 100_000)
  end

  def set_affinity(pid, aff) do
    GenServer.cast(pid, {:set_affinity, aff})
  end

  def chatter(pid, message) do
    GenServer.cast(pid, {:chatter, message})
  end

  def generate_message(message_size) do
    num_tags = Enum.random([1,2])

    # Generate random 5B types
    tags = 1..num_tags
      |> Enum.map(fn _ -> "#" <> Base.encode16(:crypto.strong_rand_bytes(4)) end)

    tag_string = Enum.join(tags, ",")
    remainder = max(0, message_size - byte_size(tag_string) - 0 - 2)

    # The final mess
    Enum.join([tag_string,
      Base.encode16(:crypto.strong_rand_bytes(remainder))
    ], " ")
  end

  ##
  # Server API
  ##
  def init([uhandle]) do
    # Create a user on the server and return the state
    # pid = GenServer.whereis({:global, TwitterEngine.CoreApi})
    TwitterEngine.CoreApi.insert_user(%User{handle: uhandle})
    {:ok, {TwitterEngine.CoreApi.get_user_by_handle(uhandle), 0, []}}
  end

  def handle_call(:get_user, _from, {user, aff, followers}) do
    {:reply, user, {user, aff, followers}}
  end

  def handle_call(:get_followers, _from, {user, aff, _followers}) do
    followers = TwitterEngine.CoreApi.get_followers(user.id)
      |> Enum.map(fn id -> TwitterEngine.CoreApi.get_user(id).handle end)
    {:reply, followers, {user, aff, followers}}
  end

  def handle_call(:populate_follower_cache, _from, {user, aff, _followers}) do
    followers = TwitterEngine.CoreApi.get_followers(user.id)
      |> Enum.map(fn id -> TwitterEngine.CoreApi.get_user(id).handle end)

    {:noreply, {user, aff, followers}}
  end

  def handle_cast({:follow, target_id}, {user, aff, followers}) do
    if user.id != target_id do
      Logger.debug "User #{user.id} following #{target_id}"
      %User{id: follower_id} = user

      TwitterEngine.CoreApi.add_follower(target_id, follower_id)
    end

    {:noreply, {user, aff, followers}}
  end

  def handle_cast({:set_affinity, aff}, state) do
    {user, _, followers} = state

    # Logger.debug "User #{user.id} tweeting affinity set to #{aff}"

    {:noreply, {user, aff, followers}}
  end

  def handle_cast({:chatter, message}, {user, aff, followers}) do
    # Logger.debug "User #{user.id} attempting to tweet message: #{message}"

    # Keep tweeting every 100ms
    new_message = generate_message(@message_size)
    # Call self again
    Process.send_after(self(), {:"$gen_cast", {:chatter, new_message}}, 10)

    TwitterEngine.CoreApi.create_tweet(user.id, message)

    {:noreply, {user, aff, followers}}
  end
end
