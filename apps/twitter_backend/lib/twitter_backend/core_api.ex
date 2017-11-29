defmodule TwitterEngine.CoreApi do
  @moduledoc """
  Workers representing the core API of our twitter clone
  """

  alias TwitterEngine.Database, as: Db

  use GenServer

  require Logger

  ##
  # Client API
  ##
  def start_link(%{db: pid}) do
    GenServer.start_link(__MODULE__, %{db: pid}, name: {:global, __MODULE__})
  end

  def get_user(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_user, user_id})
  end

  def get_user_by_handle(uhandle) do
    GenServer.call({:global, __MODULE__}, {:get_user_by_handle, uhandle})
  end

  def insert_user(user) do
    GenServer.cast({:global, __MODULE__}, {:insert_user, user})
  end

  def add_follower(target_id, follower_id) do
    GenServer.cast({:global, __MODULE__}, {:follow, target_id, follower_id})
  end

  def get_followers(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_followers, user_id})
  end

  ##
  # Server API
  ##
  def init(%{db: pid}) do
    {:ok, %{db: pid}}
  end

  #
  # Calls
  #
  def handle_call({:get_user, user_id}, _from, state) do
    {:reply, Db.get_user(state.db, user_id), state}
  end

  def handle_call({:get_user_by_handle, uhandle}, _from, state) do
    {:reply, Db.get_user_by_handle(state.db, uhandle), state}
  end

  def handle_call({:get_followers, user_id}, _from, state) do
    {:reply, Db.get_followers(state.db, user_id), state}
  end

  #
  # Casts
  #
  def handle_cast({:insert_user, user}, state) do
    Db.insert_user(state.db, user)
    {:noreply, state}
  end

  def handle_cast({:follow, target_id, follower_id}, state) do
    Db.add_follower(state.db, target_id, follower_id)
    {:noreply, state}
  end
end