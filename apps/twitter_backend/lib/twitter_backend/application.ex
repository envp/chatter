defmodule TwitterEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      worker(TwitterEngine.Feed, [], restart: :permanent),
      worker(TwitterEngine.Database, [], restart: :permanent),
      worker(TwitterEngine.CoreApi, [], restart: :permanent)
    ]

    # If any of the components fails to start or crashes, reload everything
    opts = [strategy: :one_for_all, name: TwitterEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
