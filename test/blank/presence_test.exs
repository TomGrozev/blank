defmodule Blank.PresenceTest do
  use ExUnit.Case, async: false

  describe "list_online_users/0" do
    test "returns empty list when nobody is online" do
      assert Blank.Presence.list_online_users() == []
    end
  end

  describe "subscribe/0" do
    test "subscribes to the proxy:online_users topic and receives messages" do
      assert :ok = Blank.Presence.subscribe()

      Phoenix.PubSub.broadcast(Blank.PubSub, "proxy:online_users", {:test_msg, 42})

      assert_receive {:test_msg, 42}
    end
  end

  describe "track_user/3" do
    test "tracks a user and list_online_users/0 returns the presence" do
      user = %TestApp.Accounts.User{id: 1, email: "test@example.com", name: "Test User"}

      assert {:ok, _ref} = Blank.Presence.track_user(user, "Test User", :home)

      Process.sleep(100)

      users = Blank.Presence.list_online_users()
      assert length(users) == 1

      [presence] = users
      assert presence.id == 1
      assert presence.user == "Test User"
      assert presence.schema == TestApp.Accounts.User
    end

    test "tracks user with string current_page" do
      user = %TestApp.Accounts.User{id: 2, email: "page@example.com", name: "Page User"}

      assert {:ok, _ref} = Blank.Presence.track_user(user, "Page User", "/dashboard")

      Process.sleep(100)

      users = Blank.Presence.list_online_users()
      assert length(users) >= 1

      presence = Enum.find(users, &(&1.id == 2))
      assert presence != nil
      assert presence.user == "Page User"
    end

    test "subscribe receives join notification when a user is tracked" do
      assert :ok = Blank.Presence.subscribe()

      user = %TestApp.Accounts.User{id: 3, email: "join@example.com", name: "Join User"}

      Blank.Presence.track_user(user, "Join User", :home)

      assert_receive {Blank.Presence, {:join, user_data}}, 500
      # Presence keys are stringified by the CRDT
      assert to_string(user_data.id) == "3"
      assert user_data.user == "Join User"
      assert user_data.schema == TestApp.Accounts.User
    end
  end
end
