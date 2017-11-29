defmodule TwitterEngineTest.CoreApiTest do
  use ExUnit.Case
  doctest TwitterEngine.CoreApi

  # INSERT USER
  describe "TwitterEngine.CoreApi.insert_user/1" do
    test "can insert a new user sucessfully"
    test "inserting an existing user returns an error"
  end

  describe "TwitterEngine.CoreApi.get_user/1" do
    test "fetching an existing user returns the corresponding struct"
  end

  describe "TwitterEngine.CoreApi.get_user_by_handle/1" do
    test "fetching an existing user by handle returns the corresponding struct"
    test "fetching a non existing user by id returns an error"
    test "fetching a non existing user by handle returns an error"
  end

  describe "TwitterEngine.CoreApi.add_follower/2" do
    test "existing users can follow each other"
    test "follows from a non-existent user id return an error"
    test "following a non-existent user id returns an error"
  end

  describe "TwitterEngine.CoreApi.get_followers/1" do
    test "can fetch followers of an existing user_id as a list"
    test "fetching followers of a non-existing user id returns nil"
  end
end
