defmodule TwitterEngine.CLI do

  require OptionParser
  require Logger

  defp parse_args(argv) do
    {opts, _, _} = OptionParser.parse(
      argv,
      switches: [
        mode: :string,
        address: :string,
        size: :integer
      ]
    )

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

    :global.sync

    Logger.debug("Connected to EPMD node #{remote_name}")
  end

  defp start_backend_server do
    {:ok, db_pid} = TwitterEngine.Database.start_link

    Logger.debug("Starting twitter server actor. Waiting for connections.")
    TwitterEngine.CoreApi.start_link(%{db: db_pid})
  end

  def main(argv) do
    opts = argv |> parse_args

    n_users = opts[:size] || 100

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
        start_backend_server()

        :timer.sleep(:infinity)

      "simulator" ->
        rem_name = :erlang.list_to_atom('master@' ++ to_charlist(opts[:address]))
        own_name = :erlang.list_to_atom('simulator@' ++ to_charlist(opts[:address]))

        # Set self as an EPMD node
        setup_distributed_node(own_name)

        # Attempt to join a known network that is the bee's knees or die trying
        join_or_die(rem_name)

        :global.sync

        # Start the simulator by telling it how many users to simulate
        # and where the remote process lives
        TwitterEngine.Simulator.start_link(%{user_count: n_users})

        TwitterEngine.Simulator.setup_users(:zipf)
        TwitterEngine.Simulator.start_simulation
        TwitterEngine.Simulator.print_metrics({0, :os.timestamp})

        Logger.info "End of simulation"
        # Simulation begins here
        :timer.sleep(:infinity)

      # "client" ->
        # TODO: Part 2 of project!
      _ ->
        Logger.error("Unknown option for mode: #{opts[:mode]}")
    end
  end
end

