defmodule TwitterClient do
    @moduledoc """
  -----------------------------
  TwitterClient CLI help manual

  The following commands are supported:
  * register <username>
    Register <username> with the server
  * follow <username>
    Follow user (add them to your feed) with handle <username>
  * tweet <content>
    Create a new tweet
  * retweet <tweet_id>
    Retweet an existing tweet (must know its sequence identifier)
  -----------------------------
  """
  @prompt inspect(__MODULE__) <> " $ "

  defp kind_of(cmd) do
    cmd = String.trim(cmd)
    cond do
      cmd == "help" || cmd == "h" ->
        :help
      String.starts_with?(cmd, "help ") or String.starts_with?(cmd, "h ") ->
        :help
      String.starts_with?(cmd, "register") ->
        :register
      String.starts_with?(cmd, "follow") ->
        :follow
      String.starts_with?(cmd, "tweet") ->
        :tweet
      String.starts_with?(cmd, "retweet") ->
        :retweet
      true ->
        :error
    end
  end

  defp parse(cmd) do
    kind = kind_of(cmd)
    if kind in [:help, :connect, :register, :follow, :tweet, :retweet] do
      parse(kind, cmd)
    else
      {:error, :invalid_command}
    end
  end
  defp parse(:help, _cmd) do
    :help
  end
  defp parse(:register, cmd) do
    ["register", uhandle] = String.split(cmd)
    {:register, uhandle}
  end
  defp parse(:follow, cmd) do
    ["follow", target_handle] = String.split(cmd)
    {:follow, target_handle}
  end
  defp parse(:tweet, cmd) do
    ["tweet" | text] = String.split(cmd)
    {:tweet, Enum.join(text, " ")}
  end
  defp parse(:retweet, cmd) do
    ["retweet", id] = String.split(cmd)
    {id_num, ""} = Integer.parse(id)
    {:retweet, id_num}
  end

  defp process(:help, _conn, state) do
    IO.puts @moduledoc
    state
  end
  defp process({:register, user_handle}, conn, state) do
    TwitterClient.SocketClient.register(conn, user_handle)
    Map.put(state, :handle, user_handle)
  end
  defp process({:follow, target_handle}, conn, state) do
    TwitterClient.SocketClient.follow(conn, state.handle, target_handle)
    state
  end
  defp process({:tweet, message}, conn, state) do
    TwitterClient.SocketClient.tweet(conn, state.handle, message)
    state
  end
  defp process({:retweet, id}, conn, state) do
    TwitterClient.SocketClient.retweet(conn, state.handle, id)
    state
  end
  defp process(_, conn, state), do: process(:help, conn, state)

  def input_loop(conn, state) do
    new_state = IO.gets(@prompt)
    |> parse
    |> process(conn, state)

    input_loop(conn, new_state)
  end
  def main([]) do
    # Start the command processing loop again
    {:ok, conn} = TwitterClient.SocketClient.start_link
    input_loop(conn, %{})
  end
end
