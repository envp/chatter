defmodule TwitterEngine.Feed do
  @moduledoc """
  This module serves the dual purpose of a mailbox to store notifications when
  the user is offline, or to provide a single point of access to a stream of
  notifications without bombarding the database process with the most frequent
  kind of request (Hint: READ)

  Implemented as a stack because we want the most recent messages first
  """

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def push(pid, {id, item}) do
    GenServer.cast(pid, {:push, {id, item}})
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  # Match the more specific clause first
  def pop(pid, {id, k}) do
    GenServer.call(pid, {:pop, {id, k}})
  end
  def pop(pid, id) do
    GenServer.call(pid, {:pop, id})
  end

  def peek(pid, id) do
    GenServer.call(pid, {:peek, id})
  end

  def flush_all(pid) do
    GenServer.cast(pid, :flush_all)
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

    {response, new_state} = if items == [] do
      {nil, state}
    else
      {hd(items), Map.put(state, id, tl(items))}
    end

    {:reply, response, new_state}
  end

  def handle_call({:peek, id}, _from, state) do
    items = Map.get(state, id, [])

    response = if items == [] do
      nil
    else
      hd(items)
    end

    {:reply, response, state}
  end

  def handle_cast({:push, {id, item}}, state) do
    items = Map.get(state, id, [])

    new_state = if items == [] do
      Map.put(state, id, [item])
    else
      Map.put(state, id, [item | items])
    end

    {:noreply, new_state}
  end

  def handle_cast(:flush_all, _state) do
    {:noreply, []}
  end
end
