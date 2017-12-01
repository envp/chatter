defmodule TwitterEngine.Simulator.Zipf do

  @doc """
  Get the (approximate) wieghts for a Zipf distribution with parameters
  `n`, number of ranks, and `alpha` the power-law exponent. Larger alpha leads
  to more disparity among the ranks. alpha = 0 emulates a
  uniform random distribution
  """
  def get_probabilities(n, alpha) do
    wts = 1..n
    |> Enum.map(fn x -> :math.pow(x, -alpha) end)

    # Normalize the weights
    s = Enum.sum(wts)

    wts |> Enum.map(fn wt -> wt / s end)
  end

  @doc """
  Takes two parameters, and computes a random Zipf-like assignment of elements
  from the resoures array for each rank
  """
  def assign_resources(ps, resources) do

    # Number of resources to distribute
    m = length(resources)

    ps
    |> Enum.map(fn p ->
        resources |> Enum.take_random(
          m * p
          |> :math.ceil
          |> round
        )
      end)
  end
end
