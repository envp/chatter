defmodule TwitterEngine.Tweet do
  @moduledoc """
  Module representing a tweet in the system
  """
  defstruct id: nil, message: nil

  # Parses the message to extract mentions and hashtags
  def parse(msg) do
    %{text: msg, mentions: [], hashtags: []}
  end
end
