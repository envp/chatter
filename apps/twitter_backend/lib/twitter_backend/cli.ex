defmodule TwitterEngine.CLI do
  @moduledoc """
  CLI interface for spawning TwitterEngine server, simulators and clients to
  interact with the server. Supports the following command line switches. Note
  that the server is a singleton process, there cannot be more than one of these
  on EPMD network

  A switch can be set with either --switch-name=<parameter> for non-boolean
  switches, and --switch-name for boolean switches.

  The binaries rely on EPMD running in daemon mode. Run `epmd -daemon` prior to
  executing the CLI module to ensure that is pre-condition is met. The code will
  not function without an active EPMD daemon

  --help
            Print this wall of text

  --mode=<server|simulator|client>
            server    Run the API and database servers.
            simulator Run a simulator instance to simulate parallel users
                      tweeting at each other through the API server
            client    Runs a command-based client to interact with the internals
                      of the API server

  --address=<host-addr>
            The IP address of the API server. Currently I only support 127.0.0.1
            This is a *mandatory* parameter

  --size=<k>
            The simulation size in the number of users

  --nchar=<n>
            The mean number of characters per simulated tweet, defaults to 20 or
            an average english sentence (including mentions and hashtags)
  --uname=<name>
            Username to use when registering with the API server as a client
  """
  require OptionParser
  require Logger

  defp parse_args(argv) do
    {opts, _, _} =
      OptionParser.parse(argv, switches: [
        mode: :string,
        address: :string,
        size: :integer,
        nchar: :integer,
        help: :boolean,
        uname: :string
      ])

    opts
  end

  defp setup_distributed_node(own_name) when is_atom(own_name) do
    Node.start(own_name)
    Node.set_cookie(Application.get_env(:twitter_backend, :cookie))
    Logger.debug("Created EPMD node #{Node.self()}")
  end

  defp join_or_die(remote_name) do
    if not Node.connect(remote_name) do
      Logger.error("No remote process found with name: #{remote_name}")
      exit("No remote process alive!")
    end

    :global.sync()

    Logger.debug("Connected to EPMD node #{remote_name}")
  end

  defp start_backend_server do
    {:ok, db_pid} = TwitterEngine.Database.start_link()
    {:ok, feed_pid} = TwitterEngine.Feed.start_link()

    Logger.debug("Starting twitter server actor. Waiting for connections.")
    TwitterEngine.CoreApi.start_link(%{db: db_pid, feed: feed_pid})
  end

  def main(argv) do
    opts = argv |> parse_args

    if opts[:help] do
      IO.puts(@moduledoc)
    else
      n_users = opts[:size] || 100
      tw_size = opts[:nchar] || 20

      # Need to have an address where to host/connect
      if is_nil(opts[:address]) do
        Logger.error("Please specify --address=<host-ip-address>")
        exit("Need to specify --address=<host-ip-address>")
      end

      # Process according to mode once all params are in place
      case opts[:mode] do
        "server" ->
          own_name = :erlang.list_to_atom('master@' ++ to_charlist(opts[:address]))
          setup_distributed_node(own_name)
          TwitterEngine.Application.start([], [])

          :timer.sleep(:infinity)

        "simulator" ->
          rem_name = :erlang.list_to_atom('master@' ++ to_charlist(opts[:address]))
          own_name = :erlang.list_to_atom('simulator@' ++ to_charlist(opts[:address]))

          # Set self as an EPMD node
          setup_distributed_node(own_name)

          # Attempt to join a known network that is the bee's knees or die trying
          join_or_die(rem_name)

          # Start the simulator by telling it how many users to simulate
          # and where the remote process lives
          TwitterEngine.Simulator.start_link(%{user_count: n_users, nchar: tw_size})

          TwitterEngine.Simulator.setup_users(:zipf)
          TwitterEngine.Simulator.start_simulation()
          TwitterEngine.Simulator.print_metrics({0, :os.timestamp()})

          Logger.info("End of simulation")
          # Simulation begins here
          :timer.sleep(:infinity)

        # "client" ->

        _ ->
          Logger.error("Unknown option for mode: #{opts[:mode]}")
      end
    end
  end
end
