defmodule Dialectic.Utils.SafeLogger do
  @moduledoc """
  Safe logging utilities that sanitize sensitive data before logging.

  This module provides wrapper functions around Logger that automatically
  redact sensitive information like API keys, passwords, tokens, and other
  credentials from log messages.
  """

  require Logger

  @sensitive_keys ~w(
    password
    api_key
    secret
    token
    access_token
    refresh_token
    private_key
    client_secret
    authorization
    cookie
    hashed_password
    secret_key_base
  )

  @doc """
  Logs an error with sanitized data.

  ## Examples

      SafeLogger.error("API call failed", error: error_data)
      SafeLogger.error("Operation failed", %{details: details})
  """
  def error(message, metadata \\ []) do
    sanitized_metadata = sanitize_metadata(metadata)
    Logger.error(message, sanitized_metadata)
  end

  @doc """
  Logs a warning with sanitized data.
  """
  def warning(message, metadata \\ []) do
    sanitized_metadata = sanitize_metadata(metadata)
    Logger.warning(message, sanitized_metadata)
  end

  @doc """
  Logs info with sanitized data.
  """
  def info(message, metadata \\ []) do
    sanitized_metadata = sanitize_metadata(metadata)
    Logger.info(message, sanitized_metadata)
  end

  @doc """
  Logs debug with sanitized data.
  """
  def debug(message, metadata \\ []) do
    sanitized_metadata = sanitize_metadata(metadata)
    Logger.debug(message, sanitized_metadata)
  end

  @doc """
  Sanitizes a map or keyword list by redacting sensitive keys.

  ## Examples

      iex> SafeLogger.sanitize(%{api_key: "secret", user: "john"})
      %{api_key: "[REDACTED]", user: "john"}

      iex> SafeLogger.sanitize([password: "secret", email: "test@example.com"])
      [password: "[REDACTED]", email: "test@example.com"]
  """
  def sanitize(data) when is_map(data) do
    Map.new(data, fn {key, value} ->
      {key, sanitize_value(key, value)}
    end)
  end

  def sanitize(data) when is_list(data) do
    Enum.map(data, fn
      {key, value} -> {key, sanitize_value(key, value)}
      other -> other
    end)
  end

  def sanitize(data), do: data

  # Private functions

  defp sanitize_metadata(metadata) when is_list(metadata) do
    Enum.map(metadata, fn
      {key, value} when is_atom(key) or is_binary(key) ->
        {key, sanitize_value(key, value)}

      other ->
        other
    end)
  end

  defp sanitize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn {key, value} ->
      {key, sanitize_value(key, value)}
    end)
  end

  defp sanitize_metadata(metadata), do: metadata

  defp sanitize_value(key, value) do
    key_string = to_string(key) |> String.downcase()

    if sensitive_key?(key_string) do
      "[REDACTED]"
    else
      sanitize_nested(value)
    end
  end

  defp sanitize_nested(value) when is_map(value) do
    sanitize(value)
  end

  defp sanitize_nested(value) when is_list(value) do
    Enum.map(value, &sanitize_nested/1)
  end

  defp sanitize_nested(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&sanitize_nested/1)
    |> List.to_tuple()
  end

  defp sanitize_nested(value), do: value

  defp sensitive_key?(key_string) do
    Enum.any?(@sensitive_keys, fn sensitive ->
      String.contains?(key_string, sensitive)
    end)
  end
end
