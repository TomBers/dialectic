defmodule Dialectic.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_themes ~w(default indigo violet emerald amber rose)
  @valid_avatar_types ~w(default gravatar)

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :provider, :string
    field :provider_id, :string
    field :access_token, :string

    # Profile fields
    field :username, :string
    field :display_name, :string
    field :bio, :string
    field :avatar_type, :string, default: "default"
    field :theme, :string, default: "default"
    field :website_url, :string
    field :twitter_handle, :string
    field :linkedin_url, :string

    has_many :graphs, Dialectic.Accounts.Graph, on_delete: :delete_all
    has_many :notes, Dialectic.Accounts.Note, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid theme names.
  """
  def valid_themes, do: @valid_themes

  @doc """
  Returns the list of valid avatar type names.
  """
  def valid_avatar_types, do: @valid_avatar_types

  @doc """
  Derives a default username from the user's email address.
  Takes the local part before the '@', lowercases it, strips non-alphanumeric
  characters (except hyphens), and truncates to 30 characters.
  """
  def default_username_from_email(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first("")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 30)
    |> case do
      "" -> "user"
      username -> username
    end
  end

  def default_username_from_email(_), do: "user"

  @doc """
  Returns a display-ready name: display_name if set, otherwise username,
  otherwise derived from email.
  """
  def display_name(%__MODULE__{display_name: name}) when is_binary(name) and name != "", do: name
  def display_name(%__MODULE__{username: name}) when is_binary(name) and name != "", do: name

  def display_name(%__MODULE__{email: email}) when is_binary(email),
    do: default_username_from_email(email)

  def display_name(_), do: "Anonymous"

  @doc """
  Returns the effective username for the user (stored or derived from email).
  """
  def effective_username(%__MODULE__{username: username})
      when is_binary(username) and username != "" do
    username
  end

  def effective_username(%__MODULE__{email: email}) when is_binary(email) do
    default_username_from_email(email)
  end

  def effective_username(_), do: "user"

  @doc """
  Returns the avatar URL for the user based on their avatar_type setting.
  For "gravatar", uses the Gravatar service. For "default", returns nil
  (the UI should render a default icon).
  """
  def avatar_url(%__MODULE__{avatar_type: "gravatar", email: email}) when is_binary(email) do
    hash =
      email
      |> String.trim()
      |> String.downcase()
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)

    "https://www.gravatar.com/avatar/#{hash}?s=200&d=identicon"
  end

  def avatar_url(_), do: nil

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    # Skip password validation for OAuth users
    if get_field(changeset, :provider) do
      changeset
    else
      changeset
      |> validate_required([:password])
      |> validate_length(:password, min: 12, max: 72)
      # Examples of additional password validation:
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
      |> maybe_hash_password(opts)
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Dialectic.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Dialectic.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc """
  A user changeset for OAuth registration.
  """
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :provider, :provider_id, :access_token])
    |> validate_required([:email, :provider, :provider_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Dialectic.Repo)
    |> unique_constraint(:email)
    |> put_change(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  A user changeset for updating profile fields (username, display name, bio,
  avatar type, theme, and social links).
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :display_name,
      :bio,
      :avatar_type,
      :theme,
      :website_url,
      :twitter_handle,
      :linkedin_url
    ])
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]{1,2}$/,
      message:
        "must be lowercase alphanumeric with optional hyphens, cannot start or end with a hyphen"
    )
    |> validate_length(:display_name, max: 100)
    |> validate_length(:bio, max: 500)
    |> validate_inclusion(:avatar_type, @valid_avatar_types)
    |> validate_inclusion(:theme, @valid_themes)
    |> validate_length(:website_url, max: 255)
    |> validate_format(:website_url, ~r/^(https?:\/\/)?.+\..+$/, message: "must be a valid URL")
    |> validate_length(:twitter_handle, max: 100)
    |> validate_format(:twitter_handle, ~r/^@?[A-Za-z0-9_]+$/,
      message: "must be a valid Twitter/X handle"
    )
    |> validate_length(:linkedin_url, max: 255)
    |> unsafe_validate_unique(:username, Dialectic.Repo)
    |> unique_constraint(:username)
    |> normalize_twitter_handle()
    |> normalize_website_url()
  end

  defp normalize_twitter_handle(changeset) do
    case get_change(changeset, :twitter_handle) do
      nil ->
        changeset

      "" ->
        changeset

      handle ->
        normalized = String.replace_leading(handle, "@", "")
        put_change(changeset, :twitter_handle, normalized)
    end
  end

  defp normalize_website_url(changeset) do
    case get_change(changeset, :website_url) do
      nil ->
        changeset

      "" ->
        changeset

      url ->
        if String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
          changeset
        else
          put_change(changeset, :website_url, "https://" <> url)
        end
    end
  end
end
