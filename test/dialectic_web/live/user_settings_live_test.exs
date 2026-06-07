defmodule DialecticWeb.UserSettingsLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  alias Dialectic.Accounts.ProfileBanner
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  @one_pixel_png "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change email"
      assert html =~ "Change password"
      assert html =~ "Profile photo"
      assert html =~ "avatar-cropper"
      assert html =~ "Liquid Cheese"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user email", %{conn: conn, password: password, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user password", %{conn: conn, user: user, password: password} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "update profile form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the profile form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings")

      assert html =~ "Profile"
      assert html =~ "Username"
      assert html =~ "Save profile"
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#profile_form")
        |> render_change(%{
          "user" => %{"username" => ""}
        })

      assert result =~ "can&#39;t be blank"
    end

    test "renders format errors for invalid username (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#profile_form")
        |> render_change(%{
          "user" => %{"username" => "no spaces!"}
        })

      assert result =~ "must be alphanumeric with optional hyphens"
    end

    test "renders length error for short username (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#profile_form")
        |> render_change(%{
          "user" => %{"username" => "a"}
        })

      assert result =~ "should be at least 2 character(s)"
    end

    test "renders the profile photo editor", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      assert has_element?(lv, "#avatar-upload-section")
      assert has_element?(lv, "#avatar-cropper")
      assert has_element?(lv, "#avatar-file-input")
      assert has_element?(lv, "#profile-banner-picker-button")
      assert has_element?(lv, "#banner-cropper")
      assert has_element?(lv, "#banner-file-input")
      assert has_element?(lv, "#profile-links-section")
      assert has_element?(lv, "#profile_links_form")
      assert has_element?(lv, "#profile-theme-option-emerald")
      assert has_element?(lv, ~s(input#profile-theme-value[name="user[theme]"]))
      refute has_element?(lv, "#profile-banner-picker-secondary-button")
      refute has_element?(lv, "#user_theme")
      refute has_element?(lv, "#user_profile_banner")
    end

    test "clicking a profile colour updates the profile theme value", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#profile-theme-option-emerald")
      |> render_click()

      assert has_element?(lv, ~s(input#profile-theme-value[value="emerald"]))
      assert has_element?(lv, ~s(#profile-theme-option-emerald[aria-pressed="true"]))
    end

    test "saving an uploaded banner updates the preview", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      render_hook(lv, "save_banner", %{"image_data" => @one_pixel_png})

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.banner_path =~ ~r|^/uploads/banners/banner-#{updated_user.id}-.*\.png$|
      assert has_element?(lv, ~s(img[src="#{updated_user.banner_path}"]))
    end

    test "profile validation keeps an uploaded banner preview", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      render_hook(lv, "save_banner", %{"image_data" => @one_pixel_png})

      updated_user = Accounts.get_user!(user.id)

      lv
      |> element("#profile_form")
      |> render_change(%{
        "user" => %{
          "username" => "newname42",
          "bio" => "Still thinking",
          "theme" => "emerald"
        }
      })

      assert has_element?(lv, ~s(img[src="#{updated_user.banner_path}"]))
    end

    test "clicking a profile banner preview saves that banner", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#profile-banner-option-rose-petals")
      |> render_click()

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.profile_banner == "rose-petals"
      assert has_element?(lv, ~s(img[src="#{ProfileBanner.url("rose-petals")}"]))
    end

    test "adds and saves flexible profile links", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#add-profile-link-button")
      |> render_click()

      assert has_element?(lv, "#profile_links_1_label")

      result =
        lv
        |> form("#profile_links_form", %{
          "profile_links" => %{
            "links" => %{
              "0" => %{"label" => "GitHub", "value" => "github.com/tomberman"},
              "1" => %{"label" => "Email", "value" => "hello@example.com"}
            }
          }
        })
        |> render_submit()

      assert result =~ "Profile links updated successfully"

      updated_user = Accounts.get_user!(user.id)
      assert [%{"label" => "GitHub"}, %{"label" => "Email"}] = updated_user.profile_links["links"]
    end

    test "renders profile link validation errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#profile_links_form", %{
          "profile_links" => %{
            "links" => %{"0" => %{"label" => "Bad", "value" => "javascript:alert(1)"}}
          }
        })
        |> render_submit()

      assert result =~ "HTTP(S) URLs or email"
    end

    test "updates the user profile successfully", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> element("#profile-theme-option-indigo")
      |> render_click()

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{
            "username" => "newname42",
            "bio" => "Hello world!",
            "theme" => "indigo"
          }
        })
        |> render_submit()

      assert result =~ "Profile updated successfully"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.username == "newname42"
      assert updated_user.bio == "Hello world!"
      assert updated_user.theme == "indigo"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"username" => ""}
        })
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "renders uniqueness error when username is taken", %{conn: conn} do
      other_user = user_fixture()
      Accounts.update_user_profile(other_user, %{username: "taken99"})

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"username" => "taken99"}
        })
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end
end
