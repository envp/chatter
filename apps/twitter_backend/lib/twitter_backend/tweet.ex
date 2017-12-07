defmodule TwitterEngine.Tweet do
  @moduledoc """
  Module representing a tweet in the system
  """
  defstruct id: nil,
            src_id: nil,
            creator_id: nil,
            text: nil,
            mentions: [],
            hashtags: []

  # Parses the message to extract mentions and hashtags
  def parse(msg) do
    mentions =
      Regex.scan(~r/@([\w\d_]+)/, msg)
      |> Enum.map(fn [_, capture] -> String.downcase(capture) end)
      |> Enum.uniq()

    hashtags =
      Regex.scan(~r/#([\w\d_]+)/, msg)
      |> Enum.map(fn [_, capture] -> String.downcase(capture) end)
      |> Enum.uniq()

    %__MODULE__{text: msg, mentions: mentions, hashtags: hashtags}
  end
end
