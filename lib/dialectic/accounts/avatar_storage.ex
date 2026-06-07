defmodule Dialectic.Accounts.AvatarStorage do
  @moduledoc false

  alias Dialectic.Accounts.User

  @public_prefix "/uploads/avatars"
  @max_bytes 2_000_000

  def store_user_avatar(%User{id: user_id} = user, data_url) do
    with {:ok, mime_type, bytes} <- decode_data_url(data_url),
         :ok <- validate_image_bytes(mime_type, bytes),
         {:ok, public_path} <- write_avatar(user_id, mime_type, bytes) do
      delete_avatar_path(user.avatar_path)
      {:ok, public_path}
    end
  end

  def delete_user_avatar(%User{} = user), do: delete_avatar_path(user.avatar_path)

  def delete_avatar_path(path) when is_binary(path) do
    with true <- String.starts_with?(path, @public_prefix <> "/"),
         filename <- Path.basename(path),
         full_path <- Path.join(avatars_dir(), filename) do
      File.rm(full_path)
    end

    :ok
  end

  def delete_avatar_path(_), do: :ok

  defp decode_data_url("data:" <> data_url) do
    case String.split(data_url, ",", parts: 2) do
      [metadata, encoded] ->
        mime_type = metadata |> String.split(";", parts: 2) |> List.first()

        with true <- String.ends_with?(metadata, ";base64"),
             true <- mime_type in ["image/png", "image/jpeg", "image/webp"],
             {:ok, bytes} <- Base.decode64(encoded) do
          {:ok, mime_type, bytes}
        else
          false -> {:error, :invalid_image}
          :error -> {:error, :invalid_image}
        end

      _ ->
        {:error, :invalid_image}
    end
  end

  defp decode_data_url(_), do: {:error, :invalid_image}

  defp validate_image_bytes(_mime_type, bytes) when byte_size(bytes) > @max_bytes,
    do: {:error, :too_large}

  defp validate_image_bytes("image/png", <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>>),
    do: :ok

  defp validate_image_bytes("image/jpeg", <<255, 216, 255, _::binary>>), do: :ok

  defp validate_image_bytes("image/webp", <<"RIFF", _size::binary-size(4), "WEBP", _::binary>>),
    do: :ok

  defp validate_image_bytes(_mime_type, _bytes), do: {:error, :invalid_image}

  defp write_avatar(user_id, mime_type, bytes) do
    with :ok <- File.mkdir_p(avatars_dir()),
         filename <- avatar_filename(user_id, mime_type),
         path <- Path.join(avatars_dir(), filename),
         :ok <- File.write(path, bytes) do
      {:ok, @public_prefix <> "/" <> filename}
    end
  end

  defp avatar_filename(user_id, mime_type) do
    extension = extension_for(mime_type)
    unique = System.unique_integer([:positive])
    "user-#{user_id}-#{System.system_time(:millisecond)}-#{unique}.#{extension}"
  end

  defp extension_for("image/jpeg"), do: "jpg"
  defp extension_for("image/webp"), do: "webp"
  defp extension_for(_), do: "png"

  defp avatars_dir do
    :dialectic
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("static/uploads/avatars")
  end
end
