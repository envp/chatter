defmodule TwitterEngine.CoreApi do
  @moduledoc """
  Workers representing the core API of our twitter clone
  """

  @timeout 100_000

  alias TwitterEngine.Database, as: Db
  alias TwitterEngine.Tweet

  use GenServer

  require Logger

  ##
  # Client API
  ##

  def start_link, do: start_link([])
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  def get_user(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_user, user_id}, @timeout)
  end

  def get_metrics do
    {get_last_tweet_id(), :os.timestamp()}
  end

  def get_user_by_handle(uhandle) do
    GenServer.call({:global, __MODULE__}, {:get_user_by_handle, uhandle}, @timeout)
  end

  def insert_user(user) do
    GenServer.cast({:global, __MODULE__}, {:insert_user, user})
  end

  def add_follower(target_id, follower_id) do
    GenServer.cast({:global, __MODULE__}, {:follow, target_id, follower_id})
  end

  def get_followers(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_followers, user_id}, @timeout)
  end

  def create_tweet(user_id, message) do
    GenServer.call({:global, __MODULE__}, {:create_tweet, user_id, Tweet.parse(message)}, @timeout)
  end

  def get_user_tweets(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_user_tweets, user_id}, @timeout)
  end

  def get_mention_tweets(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_mention_tweets, user_id}, @timeout)
  end

  def get_hashtag_tweets(tag) do
    GenServer.call({:global, __MODULE__}, {:get_hashtag_tweets, tag}, @timeout)
  end

  def get_last_tweet_id do
    GenServer.call({:global, __MODULE__}, :get_last_tweet_id, @timeout)
  end

  def retweet(user_id, tweet_id) do
    GenServer.cast({:global, __MODULE__}, {:retweet, tweet_id, user_id})
  end

  def get_subscriptions(user_id) do
    GenServer.call({:global, __MODULE__}, {:get_subsrciptions, user_id}, @timeout)
  end

  def get_tweet(tweet_id) do
    GenServer.call({:global, __MODULE__}, {:get_tweet, tweet_id}, @timeout)
  end

  ##
  # Server API
  ##
  def init, do: init([])
  def init(_) do
    db_pid = Process.whereis(TwitterEngine.Database)
    feed_pid = Process.whereis(TwitterEngine.Feed)
    Logger.info("Initalized API at #{inspect(self())} with db @ #{inspect(db_pid)}, feeds @ #{inspect(feed_pid)}")

    {:ok, %{}}
  end

  #
  # Calls
  #
  def handle_call({:get_user, user_id}, _from, state) do
    {:reply, Db.get_user(user_id), state}
  end

  def handle_call({:get_user_by_handle, uhandle}, _from, state) do
    {:reply, Db.get_user_by_handle(uhandle), state}
  end

  def handle_call({:get_followers, user_id}, _from, state) do
    {:reply, Db.get_followers(user_id), state}
  end

  def handle_call({:get_user_tweets, user_id}, _from, state) do
    all_tweets = Db.get_tweet_contents(user_id)

    {:reply, all_tweets, state}
  end

  def handle_call({:get_mention_tweets, user_id}, _from, state) do
    all_tweets = Db.get_mentions(user_id)

    {:reply, all_tweets, state}
  end

  def handle_call({:get_hashtag_tweets, tag}, _from, state) do
    all_tweets = Db.get_hashtag_tweets(tag)

    {:reply, all_tweets, state}
  end

  def handle_call(:get_last_tweet_id, _from, state) do
    {:reply, Db.get_last_tweet_id(), state}
  end

  def handle_call({:create_tweet, user_id, tweet}, _from, state) do
    tw_id = if Db.user_id_exists(user_id) do
      Db.insert_tweet(%{tweet | src_id: user_id, creator_id: user_id})
    else
      -1
    end

    {:reply, tw_id, state}
  end

  def handle_call({:get_subsrciptions, user_id}, _from, state) do
    {:reply, Db.get_subscriptions(user_id), state}
  end

  def handle_call({:get_tweet, tweet_id}, _from, state) do
    {:reply, Db.get_tweet(tweet_id), state}
  end

  #
  # Casts
  #
  def handle_cast({:insert_user, user}, state) do
    Db.insert_user(user)
    {:noreply, state}
  end

  def handle_cast({:follow, target_id, follower_id}, state) do
    Db.add_follower(target_id, follower_id)
    {:noreply, state}
  end

  def handle_cast({:retweet, tweet_id, user_id}, state) do
    if Db.user_id_exists(user_id) && Db.tweet_id_exists(tweet_id) do
      tweet = %{Db.get_tweet(tweet_id) | creator_id: user_id}
      Db.insert_retweet(tweet)
    end
    {:noreply, state}
  end
end
