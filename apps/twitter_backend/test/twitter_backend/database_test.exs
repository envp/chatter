defmodule TwitterEngineTest.DatabaseTest do
  use ExUnit.Case
  doctest TwitterEngine.Database

  describe "TwitterEngine.Database.insert_user/1" do
    test "can insert a new user sucessfully"
    test "inserting an existing user returns an error"
  end

  describe "TwitterEngine.Database.get_user_by_handle/1" do
    test "fetching an existing user returns the user struct"
    test "fetching an invalid user returns an error"
  end
end
