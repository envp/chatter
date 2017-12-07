defmodule TwitterEngine.Database do
  @moduledoc """
  An abstraction over the data model used by the engine.
  Uses ETS to operate on information
  """
  @timeout 100_000

  use GenServer

  require Logger

  ##
  # Client API
  ##
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_user(pid, user_id) do
    GenServer.call(pid, {:get_user, user_id}, @timeout)
  end

  def get_tweet(pid, tweet_id) do
    GenServer.call(pid, {:get_tweet, tweet_id}, @timeout)
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
    GenServer.call(pid, {:is_user_handle, uhandle}, @timeout)
  end

  def user_id_exists(pid, user_id) do
    GenServer.call(pid, {:is_user, user_id}, @timeout)
  end

  def tweet_id_exists(pid, tweet_id) do
    GenServer.call(pid, {:is_tweet, tweet_id}, @timeout)
  end

  def add_follower(pid, target_id, follower_id) do
    cond do
      target_id == follower_id ->
        :error

      user_id_exists(pid, target_id) && user_id_exists(pid, follower_id) ->
        GenServer.cast(pid, {:follow, target_id, follower_id})

      true ->
        :error
    end
  end

  def get_followers(pid, user_id) do
    if user_id_exists(pid, user_id) do
      GenServer.call(pid, {:get_followers, user_id}, @timeout)
    else
      nil
    end
  end

  def insert_tweet(pid, feed_pid, tweet) do
    # Specifically this to ensure that tweet sequence numbers are increasing
    GenServer.cast(pid, {:insert_tweet, feed_pid, tweet})
  end

  def insert_retweet(pid, feed_pid, tweet) do
    # Specifically this to ensure that tweet sequence numbers are increasing
    GenServer.cast(pid, {:insert_retweet, feed_pid, tweet})
  end

  def get_tweet_ids(pid, user_id) do
    GenServer.call(pid, {:get_tweet_ids, user_id}, @timeout)
  end

  def get_tweet_contents(pid, ids) when is_list(ids) do
    GenServer.call(pid, {:get_tweet_contents, ids})
  end

  def get_tweet_contents(pid, tweet_id), do: get_tweet_contents(pid, [tweet_id])

  def get_mentions(pid, user_id) do
    GenServer.call(pid, {:get_mentions, user_id}, @timeout)
  end

  def get_hashtag_tweets(pid, tag) do
    GenServer.call(pid, {:get_hashtag_tweets, tag})
  end

  def get_last_tweet_id(pid) do
    GenServer.call(pid, :get_last_tweet_id, @timeout)
  end

  ##
  # Server API
  ##
  def init(:ok) do
    Logger.info("Initializing database at #{inspect(self())}")
    # Table of users
    :ets.new(:users, [
      :set,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Table of tweet records
    :ets.new(:tweets, [
      :set,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Table of tweet ids for each user id
    :ets.new(:user_tweets, [
      :bag,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Table of tweet ids for each user mention
    :ets.new(:mentions, [
      :bag,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Table of tweet ids for each hashtag
    :ets.new(:hashtags, [
      :bag,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # User ids linked to each follower id
    :ets.new(:followers, [
      :bag,
      :private,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Inverse-map of user handle to user id
    user_inverse = %{}

    # The state is represented by the user and tweet sequence numbers
    {:ok, {0, 0, user_inverse}}
  end

  #
  # Calls
  #
  def handle_call({:is_user, user_id}, _from, state) do
    Logger.debug("Query {:is_user, #{inspect(user_id)}}")

    response = :ets.member(:users, user_id)

    {:reply, response, state}
  end

  def handle_call({:is_tweet, tweet_id}, _from, state) do
    Logger.debug("Query {:is_tweet, #{inspect(tweet_id)}}")

    response = :ets.member(:tweets, tweet_id)

    {:reply, response, state}
  end

  def handle_call({:is_user_handle, uhandle}, _from, state) do
    Logger.debug("Query {:is_user_handle, #{uhandle}}")

    {_, _, user_inverse} = state
    {:reply, Map.has_key?(user_inverse, uhandle), state}
  end

  def handle_call({:get_user, user_id}, _from, state) do
    Logger.debug("Query {:get_user, #{user_id}}")

    # There is only 1 user per id
    response =
      case :ets.lookup(:users, user_id) do
        [{_, user}] ->
          user

        [] ->
          :error
      end

    Logger.debug("Response {:get_user, #{user_id}}: #{inspect(response)}")
    {:reply, response, state}
  end

  def handle_call({:get_tweet, tweet_id}, _from, state) do
    Logger.debug("Query {:get_tweet, #{tweet_id}}")

    # There is only 1 user per id
    response =
      case :ets.lookup(:tweets, tweet_id) do
        [{_, tweet}] ->
          tweet

        [] ->
          :error
      end

    Logger.debug("Response {:get_tweet, #{tweet_id}}: #{inspect(response)}")
    {:reply, response, state}
  end

  def handle_call({:get_user_by_handle, uhandle}, _from, state) do
    Logger.debug("Query {:get_user_by_handle, #{uhandle}}")
    {_, _, user_inverse} = state

    user_id = Map.get(user_inverse, uhandle)
    # There is only 1 user per id
    response =
      case :ets.lookup(:users, user_id) do
        [{_, user}] ->
          user

        [] ->
          :error
      end

    Logger.debug("Response {:get_user_by_handle, #{uhandle}}: #{inspect(response)}")
    {:reply, response, state}
  end

  def handle_call({:get_followers, user_id}, _from, state) do
    Logger.debug("Query {:get_followers, #{user_id}}")

    followers = :ets.lookup(:followers, user_id) |> Enum.map(fn {_, v} -> v end)

    Logger.debug("Response {:get_followers, #{user_id}}: #{inspect(followers)}")
    {:reply, followers, state}
  end

  def handle_call({:get_tweet_ids, user_id}, _from, state) do
    Logger.debug("Query {:get_tweet_ids, #{user_id}}")

    ids = :ets.lookup(:user_tweets, user_id) |> Enum.map(fn {_, v} -> v end)

    Logger.debug("Response {:get_tweet_ids, #{user_id}}: #{inspect(ids)}")
    {:reply, ids, state}
  end

  def handle_call({:get_tweet_contents, user_id}, _from, state) do
    Logger.debug("Query {:get_tweet_contents, #{user_id}}")

    contents =
      :ets.lookup(:user_tweets, user_id)
      |> Enum.map(fn {_, v} -> v end)
      |> Enum.map(fn id ->
           case :ets.lookup(:tweets, id) do
             [{_, tweet}] ->
               tweet

             _ ->
               nil
           end
         end)
      |> Enum.filter(fn twt -> !is_nil(twt) end)

    Logger.debug("Response {:get_tweet_contents, #{user_id}}: #{inspect(contents)}")
    {:reply, contents, state}
  end

  def handle_call({:get_mentions, user_id}, _from, state) do
    Logger.debug("Query {:get_mentions, #{user_id}}")

    tweets =
      :ets.lookup(:mentions, user_id)
      |> Enum.map(fn {_, v} -> v end)
      |> Enum.map(fn id ->
           case :ets.lookup(:tweets, id) do
             [{_, tweet}] ->
               tweet

             _ ->
               nil
           end
         end)
      |> Enum.filter(fn twt -> !is_nil(twt) end)

    Logger.debug("Query {:get_mentions, #{user_id}}: #{inspect(tweets)}")
    {:reply, tweets, state}
  end

  def handle_call({:get_hashtag_tweets, tag}, _from, state) do
    Logger.debug("Query {:get_hashtag_tweets, #{tag}}")

    tweets =
      :ets.lookup(:hashtags, tag)
      |> Enum.map(fn {_, v} -> v end)
      |> Enum.map(fn id ->
           case :ets.lookup(:tweets, id) do
             [{_, tweet}] ->
               tweet

             _ ->
               nil
           end
         end)
      |> Enum.filter(fn twt -> !is_nil(twt) end)

    Logger.debug("Query {:get_hashtag_tweets, #{tag}}: #{inspect(tweets)}")

    {:reply, tweets, state}
  end

  def handle_call(:get_last_tweet_id, _from, state) do
    {_, result, _} = state
    {:reply, result, state}
  end

  #
  # Casts
  #
  def handle_cast({:insert_user, user}, state) do
    {user_seqnum, tweet_seqnum, user_inverse} = state

    user = %{user | id: user_seqnum + 1}
    :ets.insert(:users, {user_seqnum + 1, user})
    user_inverse = Map.put(user_inverse, user.handle, user_seqnum + 1)

    Logger.debug("Insert user #{inspect(user)}")
    {:noreply, {user_seqnum + 1, tweet_seqnum, user_inverse}}
  end

  def handle_cast({:follow, target_id, follower_id}, state) do
    Logger.debug("User #{follower_id} followed User #{target_id}")

    :ets.insert(:followers, {target_id, follower_id})
    {:noreply, state}
  end

  def handle_cast({:insert_tweet, feed_pid, tweet}, {user_seqnum, tweet_seqnum, user_inverse}) do
    tweet = %{tweet | id: tweet_seqnum + 1}

    Logger.debug("Insert tweet #{inspect(tweet)}")

    # Insert it into the primary table storing tweets sequentially
    :ets.insert(:tweets, {tweet.id, tweet})

    # Add a reference to the row number in the user_tweets table
    :ets.insert(:user_tweets, {tweet.creator_id, tweet.id})

    # Add this user's tweet to the follower's feed
    :ets.lookup(:followers, tweet.creator_id)
    |> Enum.map(fn {_, v} -> v end)
    |> Enum.each(fn f_id ->
         TwitterEngine.Feed.push(feed_pid, {f_id, tweet.id})
       end)

    # Insert this tweet id for its mentions
    tweet.mentions
    |> Enum.map(fn uhandle -> Map.fetch(user_inverse, uhandle) end)
    |> Enum.each(fn m_id ->
         # Insert into mentions
         :ets.insert(:mentions, {m_id, tweet.id})

         # Also record this in the feed
         TwitterEngine.Feed.push(feed_pid, {m_id, tweet.id})
       end)

    # Insert this tweet into its hashtags table
    tweet.hashtags
    |> Enum.each(fn htag -> :ets.insert(:hashtags, {htag, tweet.id}) end)

    {:noreply, {user_seqnum, tweet_seqnum + 1, user_inverse}}
  end

  def handle_cast({:insert_retweet, feed_pid, tweet}, {user_seqnum, tweet_seqnum, user_inverse}) do
    tweet = %{tweet | id: tweet_seqnum + 1}

    Logger.debug("Insert re-tweet #{inspect(tweet)}")

    # Insert it into the primary table storing tweets sequentially
    :ets.insert(:tweets, {tweet.id, tweet})

    # Add a reference to the row number in the user_tweets table
    :ets.insert(:user_tweets, {tweet.creator_id, tweet.id})

    # Add this user's tweet to the follower's feed
    :ets.lookup(:followers, tweet.creator_id)
    |> Enum.map(fn {_, v} -> v end)
    |> Enum.each(fn f_id ->
         TwitterEngine.Feed.push(feed_pid, {f_id, tweet.id})
       end)

    ##################################################################
    ## Re-tweets do not undergo the mention and hashtags processing ##
    ##################################################################

    # # Insert this tweet id for its mentions
    # tweet.mentions
    # |> Enum.map(fn uhandle -> Map.fetch(user_inverse, uhandle) end)
    # |> Enum.each(fn m_id ->
    #   # Insert into mentions
    #   :ets.insert(:mentions, {m_id, tweet.id})

    #   # Also record this in the feed
    #   TwitterEngine.Feed.push(feed_pid, {m_id, tweet.id})
    # end)

    # # Insert this tweet into its hashtags table
    # tweet.hashtags
    # |> Enum.each(fn htag -> :ets.insert(:hashtags, {htag, tweet.id}) end)

    {:noreply, {user_seqnum, tweet_seqnum + 1, user_inverse}}
  end
end
