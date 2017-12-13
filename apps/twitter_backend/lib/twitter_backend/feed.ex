defmodule TwitterEngine.Feed do
  @moduledoc """
  This module serves the dual purpose of a mailbox to store notifications when
  the user is offline, or to provide a single point of access to a stream of
  notifications without bombarding the database process with the most frequent
  kind of request (Hint: READ)

  Implemented as a stack because we want the most recent messages first.

  If the stack reaches its maximum size, the bottom half
  is automatically discarded
  """

  use GenServer

  require Logger

  @max_size 1024

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def push({id, item}) do
    GenServer.cast(__MODULE__, {:push, {id, item}})
  end

  def state do
    GenServer.call(__MODULE__, :state)
  end

  # Match the more specific clause first
  def pop({id, k}) do
    GenServer.call(__MODULE__, {:pop, {id, k}})
  end

  def pop(id) do
    GenServer.call(__MODULE__, {:pop, id})
  end

  def peek(id) do
    GenServer.call(__MODULE__, {:peek, id})
  end

  def flush_all do
    GenServer.cast(__MODULE__, :flush_all)
  end

  def live_feed({node, remote_pid, id}) do
    spawn(fn ->
      item = pop(id)
      :rpc.call(node, UserProcess, :print_tweet, item)
      online = :rpc.call(node, UserProcess, :is_online, remote_pid)
      if item != [] && online, do: live_feed({node, id})
    end)
  end

  def init([]) do
    {:ok, %{}}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:pop, {id, k}}, _from, state) do
    items = Map.get(state, id, [])

    {response, remainder} = Enum.split(items, k)
    new_state = Map.put(state, id, remainder)

    {:reply, response, new_state}
  end

  def handle_call({:pop, id}, _from, state) do
    items = Map.get(state, id, [])

    {response, new_state} =
      if items == [] do
        {nil, state}
      else
        {hd(items), Map.put(state, id, tl(items))}
      end

    {:reply, response, new_state}
  end

  def handle_call({:peek, id}, _from, state) do
    items = Map.get(state, id, [])

    response =
      if items == [] do
        nil
      else
        hd(items)
      end

    {:reply, response, state}
  end

  def handle_cast({:push, {id, item}}, state) do
    items = Map.get(state, id, [])

    new_state =
      if items == [] do
        Map.put(state, id, [item])
      else
        # Check for potential overflow and discard the bottom half
        {trimmed_items, _} =
          if length(items) >= @max_size do
            Logger.debug("Trimming feed storage for user: #{id}")
            n = (length(items) / 2) |> :math.floor() |> round

            Enum.split(items, n)
          else
            {items, []}
          end

        Map.put(state, id, [item | trimmed_items])
      end

    {:noreply, new_state}
  end

  def handle_cast(:flush_all, _state) do
    {:noreply, []}
  end
end
