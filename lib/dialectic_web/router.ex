defmodule DialecticWeb.Router do
  use DialecticWeb, :router

  import DialecticWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DialecticWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DialecticWeb do
    pipe_through :browser
    get "/", PageController, :home
    get "/my/ideas", PageController, :my_graphs
    get "/view_all/graphs", PageController, :view_all
    post "/conversation", PageController, :create
    # get "/intro/what", PageController, :what
    get "/intro/how", PageController, :guide

    get "/deploy/dashboard", PageController, :deploy_dashboard
    get "/ideas/all", PageController, :ideas_all
    live "/start/new/idea", FocusLive
    live "/:graph_name", GraphLive
    live "/:graph_name/linear", LinearGraphLive
    live "/:graph_name/story/:node_id", StoryLive
    live "/:graph_name/focus/:node_id", FocusLive
  end

  # Other scopes may use custom stacks.
  scope "/api", DialecticWeb do
    pipe_through :api

    get "/random_question", PageController, :random_question
    get "/graphs/json/:graph_name", PageController, :graph_json
    get "/graphs/md/:graph_name", PageController, :graph_md
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dialectic, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DialecticWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", DialecticWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{DialecticWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", DialecticWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{DialecticWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", DialecticWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{DialecticWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
