defmodule TwitterEngine.Database do
  @moduledoc """
  An abstraction over the data model used by the engine.
  Uses ETS to operate on information
  """

  use GenServer
  ##
  # Client API
  ##
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_user(pid, user_id) do
    GenServer.call(pid , {:get_user, user_id})
  end

  def get_user_by_handle(pid, uhandle) do
    GenServer.call(pid, {:get_user_by_handle, uhandle})
  end

  def insert_user(pid, user) do
    if user_handle_exists(pid, user.handle) do
      :error
    else
      GenServer.cast(pid, {:insert_user, user})
    end
  end

  def user_handle_exists(pid, uhandle) do
    GenServer.call(pid, {:is_user_handle, uhandle})
  end

  def user_id_exists(pid, user_id) do
    GenServer.call(pid, {:is_user, user_id})
  end

  def add_follower(pid, target_id, follower_id) do
    if user_id_exists(pid, target_id) && user_id_exists(pid, follower_id) do
      GenServer.cast(pid, {:follow, target_id, follower_id})
    else
      :error
    end
  end

  def get_followers(pid, user_id) do
    if user_id_exists(pid, user_id) do
      GenServer.call(pid, {:get_followers, user_id})
    else
      nil
    end
  end

  ##
  # Server API
  ##
  def init(:ok) do
    :ets.new(:users, [:set, :private, :named_table])
    :ets.new(:tweets, [:set, :private, :named_table])
    :ets.new(:followers, [:bag, :private, :named_table])

    user_inverse  = %{}


    # The state is represented by just the sequence number
    {:ok, {0, user_inverse}}
  end

  #
  # Calls
  #
  def handle_call({:is_user, user_id}, _from, state) do
    {_, user_inverse} = state

    response = case :ets.lookup(:users, user_id) do
      [{_, user}] ->
        true
      [] ->
        false
    end

    {:reply, response, state}
  end

  def handle_call({:is_user_handle, uhandle}, _from, state) do
    {_, user_inverse} = state
    {:reply, Map.has_key?(user_inverse, uhandle), state}
  end

  def handle_call({:get_user, user_id}, _from, state) do
    # There is only 1 user per id
    response = case :ets.lookup(:users, user_id) do
      [{_, user}] ->
        user
      [] ->
        :error
    end

    {:reply, response, state}
  end

  def handle_call({:get_user_by_handle, uhandle}, _from, state) do
    {_, user_inverse} = state

    user_id = Map.get(user_inverse, uhandle)
    # There is only 1 user per id
    response = case :ets.lookup(:users, user_id) do
      [{_, user}] ->
        user
      [] ->
        :error
    end

    {:reply, response, state}
  end

  def handle_call({:get_followers, user_id}, _from, state) do
    followers = :ets.lookup(:followers, user_id) |> Enum.map(fn {k ,v} -> v end)

    {:reply, followers, state}
  end

  #
  # Casts
  #
  def handle_cast({:insert_user, user}, state) do
    {seqnum, user_inverse} = state

    user = %{user | id: seqnum + 1}

    :ets.insert(:users, {seqnum + 1, user})
    user_inverse = Map.put(user_inverse, user.handle, seqnum + 1)

    {:noreply, {seqnum + 1, user_inverse}}
  end

  def handle_cast({:follow, target_id, follower_id}, state) do
    :ets.insert(:followers, {target_id, follower_id})
    {:noreply, state}
  end
end
