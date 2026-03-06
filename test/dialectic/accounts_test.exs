defmodule Dialectic.AccountsTest do
  use Dialectic.DataCase

  alias Dialectic.Accounts

  import Dialectic.AccountsFixtures
  alias Dialectic.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "find_or_create_oauth_user/1" do
    test "creates a new OAuth user" do
      oauth_attrs = %{
        email: "oauth@example.com",
        provider: "google",
        provider_id: "12345",
        access_token: "token123"
      }

      assert {:ok, user} = Accounts.find_or_create_oauth_user(oauth_attrs)
      assert user.email == "oauth@example.com"
      assert user.provider == "google"
      assert user.provider_id == "12345"
      assert user.access_token == "token123"
      assert is_nil(user.hashed_password)
      assert not is_nil(user.confirmed_at)
    end

    test "updates access token for existing OAuth user" do
      oauth_attrs = %{
        email: "oauth@example.com",
        provider: "google",
        provider_id: "12345",
        access_token: "token123"
      }

      assert {:ok, user} = Accounts.find_or_create_oauth_user(oauth_attrs)
      original_id = user.id

      # Try to create again with new token - should update
      updated_attrs = %{
        email: "oauth@example.com",
        provider: "google",
        provider_id: "12345",
        access_token: "new_token456"
      }

      assert {:ok, updated_user} = Accounts.find_or_create_oauth_user(updated_attrs)
      assert updated_user.id == original_id
      assert updated_user.access_token == "new_token456"
    end

    test "handles concurrent OAuth requests gracefully" do
      oauth_attrs = %{
        email: "concurrent@example.com",
        provider: "google",
        provider_id: "concurrent123",
        access_token: "token1"
      }

      # Simulate concurrent requests by calling twice
      task1 = Task.async(fn -> Accounts.find_or_create_oauth_user(oauth_attrs) end)
      task2 = Task.async(fn -> Accounts.find_or_create_oauth_user(oauth_attrs) end)

      result1 = Task.await(task1)
      result2 = Task.await(task2)

      # Both should succeed
      assert {:ok, user1} = result1
      assert {:ok, user2} = result2

      # Should be the same user
      assert user1.id == user2.id
      assert user1.provider_id == "concurrent123"
    end

    test "validates email uniqueness across all users" do
      email = "unique@example.com"

      google_attrs = %{
        email: email,
        provider: "google",
        provider_id: "google123",
        access_token: "google_token"
      }

      github_attrs = %{
        email: email,
        provider: "github",
        provider_id: "github123",
        access_token: "github_token"
      }

      # First OAuth user succeeds
      assert {:ok, _google_user} = Accounts.find_or_create_oauth_user(google_attrs)

      # Second OAuth user with same email fails due to unique email constraint
      assert {:error, changeset} = Accounts.find_or_create_oauth_user(github_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  ## Profile

  describe "generate_unique_username/1" do
    test "derives username from email local part" do
      username = Accounts.generate_unique_username("alice@example.com")
      assert username == "alice"
    end

    test "strips invalid characters and normalizes" do
      username = Accounts.generate_unique_username("Alice.O'Brien@example.com")
      assert username == "aliceobrien"
    end

    test "appends suffix when base username is already taken" do
      user = user_fixture(%{email: "taken@example.com"})
      assert user.username == "taken"

      username = Accounts.generate_unique_username("taken@example.com")
      assert username != "taken"
      assert String.starts_with?(username, "taken-")
    end

    test "returns a fallback for nil input" do
      username = Accounts.generate_unique_username(nil)
      assert is_binary(username)
      assert username == "user" or String.starts_with?(username, "user-")
    end

    test "returns a suffixed fallback for nil input when 'user' is taken" do
      _user = user_fixture(%{email: "user@example.com"})
      username = Accounts.generate_unique_username(nil)
      assert is_binary(username)
      assert String.starts_with?(username, "user-")
    end

    test "skips reserved usernames and appends a suffix" do
      # "admin" is reserved, so generating from "admin@example.com"
      # should never return the bare "admin" base name
      username = Accounts.generate_unique_username("admin@example.com")
      assert username != "admin"
      assert String.starts_with?(username, "admin-")
    end

    test "skips reserved usernames for other reserved words" do
      for reserved <- ~w(settings support system login) do
        username = Accounts.generate_unique_username("#{reserved}@example.com")

        assert username != reserved,
               "expected generate_unique_username to skip reserved name #{inspect(reserved)}"

        assert String.starts_with?(username, "#{reserved}-")
      end
    end
  end

  describe "auto-assigned username at registration" do
    test "register_user/1 auto-assigns a username from the email" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(%{email: email, password: valid_user_password()})

      expected_base = Dialectic.Accounts.User.default_username_from_email(email)
      assert user.username == expected_base
    end

    test "register_user/1 handles username collision with suffix" do
      email = "collide@example.com"
      {:ok, first} = Accounts.register_user(%{email: email, password: valid_user_password()})
      assert first.username == "collide"

      email2 = "collide@other.com"
      {:ok, second} = Accounts.register_user(%{email: email2, password: valid_user_password()})
      assert second.username != "collide"
      assert String.starts_with?(second.username, "collide-")
    end

    test "find_or_create_oauth_user/1 auto-assigns a username" do
      attrs = %{
        email: "oauth-#{System.unique_integer([:positive])}@example.com",
        provider: "google",
        provider_id: "google-#{System.unique_integer([:positive])}",
        access_token: "token123"
      }

      {:ok, user} = Accounts.find_or_create_oauth_user(attrs)
      assert is_binary(user.username)
      assert user.username != ""
    end
  end

  describe "get_user_by_username/1" do
    test "returns nil when no user has the given username" do
      assert Accounts.get_user_by_username("nonexistent") == nil
    end

    test "returns the user with a matching stored username" do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_profile(user, %{username: "alice42"})
      assert Accounts.get_user_by_username("alice42").id == user.id
    end

    test "lookup is case-insensitive (citext column)" do
      user = user_fixture()
      {:ok, _user} = Accounts.update_user_profile(user, %{username: "Alice42"})
      assert Accounts.get_user_by_username("alice42").id == user.id
      assert Accounts.get_user_by_username("ALICE42").id == user.id
    end
  end

  describe "get_user_for_profile/1" do
    test "returns nil when no user has the given username" do
      assert Accounts.get_user_for_profile("nobody") == nil
    end

    test "returns the user by stored username" do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_profile(user, %{username: "bob99"})
      assert Accounts.get_user_for_profile("bob99").id == user.id
    end

    test "finds user by auto-assigned username derived from email" do
      user = user_fixture(%{email: "alice@example.com"})
      assert Accounts.get_user_for_profile("alice").id == user.id
    end
  end

  describe "update_user_profile/2" do
    test "updates username, bio, and theme" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user_profile(user, %{
                 username: "newname",
                 bio: "Hello!",
                 theme: "indigo"
               })

      assert updated.username == "newname"
      assert updated.bio == "Hello!"
      assert updated.theme == "indigo"
    end

    test "rejects blank username" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: ""})
      assert "can't be blank" in errors_on(changeset).username
    end

    test "rejects username shorter than 2 characters" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: "a"})
      assert "should be at least 2 character(s)" in errors_on(changeset).username
    end

    test "rejects username with invalid characters" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: "bad name!"})

      assert "must be alphanumeric with optional hyphens, cannot start or end with a hyphen" in errors_on(
               changeset
             ).username
    end

    test "enforces username uniqueness" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} = Accounts.update_user_profile(user1, %{username: "unique99"})
      assert {:error, changeset} = Accounts.update_user_profile(user2, %{username: "unique99"})
      assert "has already been taken" in errors_on(changeset).username
    end

    test "allows empty gravatar_id (normalizes blank to nil)" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user_profile(user, %{username: "test22", gravatar_id: ""})

      assert updated.gravatar_id == nil
    end

    test "rejects invalid theme" do
      user = user_fixture()

      assert {:error, changeset} =
               Accounts.update_user_profile(user, %{username: "test22", theme: "neon"})

      assert "is invalid" in errors_on(changeset).theme
    end

    test "rejects reserved usernames" do
      user = user_fixture()

      for name <- ~w(admin settings support system users login) do
        assert {:error, changeset} = Accounts.update_user_profile(user, %{username: name}),
               "expected reserved username #{inspect(name)} to be rejected"

        assert "is reserved and cannot be used" in errors_on(changeset).username
      end
    end

    test "rejects reserved usernames case-insensitively" do
      user = user_fixture()

      for name <- ~w(Admin ADMIN Settings SYSTEM) do
        assert {:error, changeset} = Accounts.update_user_profile(user, %{username: name}),
               "expected reserved username #{inspect(name)} to be rejected"

        assert "is reserved and cannot be used" in errors_on(changeset).username
      end
    end

    test "allows non-reserved usernames" do
      user = user_fixture()

      assert {:ok, updated} = Accounts.update_user_profile(user, %{username: "tom42"})
      assert updated.username == "tom42"
    end
  end

  describe "get_profile_stats/2" do
    test "returns zero stats for user with no graphs" do
      user = user_fixture()
      stats = Accounts.get_profile_stats(user)
      assert stats.graphs_created == 0
      assert stats.total_nodes == 0
      assert stats.member_since == user.inserted_at
    end

    test "counts public published graphs and their non-compound nodes" do
      user = user_fixture()

      nodes = [
        %{"id" => "1", "label" => "A"},
        %{"id" => "2", "label" => "B"},
        %{"id" => "3", "label" => "C", "compound" => true}
      ]

      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "graph-stats-#{System.unique_integer([:positive])}",
        slug: "slug-stats-#{System.unique_integer([:positive])}",
        data: %{"nodes" => nodes},
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      stats = Accounts.get_profile_stats(user)
      assert stats.graphs_created == 1
      # 2 non-compound nodes
      assert stats.total_nodes == 2
    end

    test "accepts pre-fetched graphs list" do
      user = user_fixture()
      graphs = Accounts.list_user_public_graphs(user)
      stats = Accounts.get_profile_stats(user, graphs)
      assert stats.graphs_created == 0
    end
  end

  describe "get_common_tags/2" do
    test "returns empty list for user with no graphs" do
      user = user_fixture()
      assert Accounts.get_common_tags(user) == []
    end

    test "returns tags sorted by frequency" do
      user = user_fixture()

      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "graph-tags1-#{System.unique_integer([:positive])}",
        slug: "slug-tags1-#{System.unique_integer([:positive])}",
        data: %{},
        tags: ["elixir", "phoenix"],
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "graph-tags2-#{System.unique_integer([:positive])}",
        slug: "slug-tags2-#{System.unique_integer([:positive])}",
        data: %{},
        tags: ["elixir", "liveview"],
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      tags = Accounts.get_common_tags(user)
      # "elixir" appears twice, so it should be first
      assert hd(tags) == "elixir"
      assert length(tags) == 3
    end

    test "respects limit option" do
      user = user_fixture()

      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "graph-taglimit-#{System.unique_integer([:positive])}",
        slug: "slug-taglimit-#{System.unique_integer([:positive])}",
        data: %{},
        tags: ["a", "b", "c", "d", "e", "f"],
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      assert length(Accounts.get_common_tags(user, limit: 2)) == 2
    end

    test "accepts pre-fetched graphs" do
      user = user_fixture()
      graphs = Accounts.list_user_public_graphs(user)
      assert Accounts.get_common_tags(user, graphs: graphs) == []
    end
  end

  describe "list_user_public_graphs/1" do
    test "returns empty list for user with no graphs" do
      user = user_fixture()
      assert Accounts.list_user_public_graphs(user) == []
    end

    test "returns only public, published, non-deleted graphs" do
      user = user_fixture()

      # Public + published — should appear
      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "visible-#{System.unique_integer([:positive])}",
        slug: "slug-visible-#{System.unique_integer([:positive])}",
        data: %{},
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      # Private — should not appear
      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "private-#{System.unique_integer([:positive])}",
        slug: "slug-private-#{System.unique_integer([:positive])}",
        data: %{},
        is_public: false,
        is_published: true,
        is_deleted: false,
        user_id: user.id
      })

      # Deleted — should not appear
      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "deleted-#{System.unique_integer([:positive])}",
        slug: "slug-deleted-#{System.unique_integer([:positive])}",
        data: %{},
        is_public: true,
        is_published: true,
        is_deleted: true,
        user_id: user.id
      })

      # Not published — should not appear
      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "draft-#{System.unique_integer([:positive])}",
        slug: "slug-draft-#{System.unique_integer([:positive])}",
        data: %{},
        is_public: true,
        is_published: false,
        is_deleted: false,
        user_id: user.id
      })

      graphs = Accounts.list_user_public_graphs(user)
      assert length(graphs) == 1
      assert hd(graphs).is_public == true
      assert hd(graphs).is_published == true
    end

    test "does not return graphs from other users" do
      user1 = user_fixture()
      user2 = user_fixture()

      Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
        title: "other-user-graph-#{System.unique_integer([:positive])}",
        slug: "slug-other-#{System.unique_integer([:positive])}",
        data: %{},
        is_public: true,
        is_published: true,
        is_deleted: false,
        user_id: user2.id
      })

      assert Accounts.list_user_public_graphs(user1) == []
    end
  end
end
