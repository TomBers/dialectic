defmodule Dialectic.Accounts.AvatarStorage do
  @moduledoc false

  alias Dialectic.Accounts.User

  @avatar_prefix "/uploads/avatars"
  @banner_prefix "/uploads/banners"
  @max_bytes 4_000_000

  def store_user_avatar(%User{id: user_id} = user, data_url) do
    with {:ok, public_path} <- store_user_image(user_id, data_url, :avatar) do
      delete_avatar_path(user.avatar_path)
      {:ok, public_path}
    end
  end

  def store_user_banner(%User{id: user_id} = user, data_url) do
    with {:ok, public_path} <- store_user_image(user_id, data_url, :banner) do
      delete_banner_path(user.banner_path)
      {:ok, public_path}
    end
  end

  def delete_user_avatar(%User{} = user), do: delete_avatar_path(user.avatar_path)
  def delete_user_banner(%User{} = user), do: delete_banner_path(user.banner_path)

  def delete_avatar_path(path), do: delete_path(path, @avatar_prefix, images_dir(:avatar))
  def delete_banner_path(path), do: delete_path(path, @banner_prefix, images_dir(:banner))

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

  defp store_user_image(user_id, data_url, kind) do
    with {:ok, mime_type, bytes} <- decode_data_url(data_url),
         :ok <- validate_image_bytes(mime_type, bytes),
         {:ok, public_path} <- write_image(user_id, mime_type, bytes, kind) do
      {:ok, public_path}
    end
  end

  defp write_image(user_id, mime_type, bytes, kind) do
    with :ok <- File.mkdir_p(images_dir(kind)),
         filename <- image_filename(user_id, mime_type, kind),
         path <- Path.join(images_dir(kind), filename),
         :ok <- File.write(path, bytes) do
      {:ok, public_prefix(kind) <> "/" <> filename}
    end
  end

  defp image_filename(user_id, mime_type, kind) do
    extension = extension_for(mime_type)
    unique = System.unique_integer([:positive])
    "#{kind}-#{user_id}-#{System.system_time(:millisecond)}-#{unique}.#{extension}"
  end

  defp extension_for("image/jpeg"), do: "jpg"
  defp extension_for("image/webp"), do: "webp"
  defp extension_for(_), do: "png"

  defp delete_path(path, prefix, directory) when is_binary(path) do
    with true <- String.starts_with?(path, prefix <> "/"),
         filename <- Path.basename(path),
         full_path <- Path.join(directory, filename) do
      File.rm(full_path)
    end

    :ok
  end

  defp delete_path(_path, _prefix, _directory), do: :ok

  defp public_prefix(:avatar), do: @avatar_prefix
  defp public_prefix(:banner), do: @banner_prefix

  defp images_dir(kind) do
    :dialectic
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("static" <> public_prefix(kind))
  end
end
