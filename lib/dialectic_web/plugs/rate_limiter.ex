defmodule DialecticWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug to prevent abuse of authentication and API endpoints.

  Uses Hammer for distributed rate limiting with configurable limits per endpoint type.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @env Mix.env()

  @doc """
  Rate limits requests based on endpoint type and client IP.

  ## Options

    * `:type` - The type of endpoint being rate limited. One of:
      - `:auth` - Authentication endpoints (login, registration)
      - `:api` - General API endpoints
      - `:llm` - LLM/AI generation endpoints

  ## Examples

      plug DialecticWeb.Plugs.RateLimiter, type: :auth

  """
  def init(opts), do: opts

  def call(conn, opts) do
    # Skip rate limiting in test environment
    if @env == :test do
      conn
    else
      type = Keyword.get(opts, :type, :api)
      {limit, scale_ms} = get_limits(type)

      # Get identifier (IP address or user_id if authenticated)
      identifier = get_identifier(conn, type)
      bucket_key = "rate_limit:#{type}:#{identifier}"

      case Hammer.check_rate(bucket_key, scale_ms, limit) do
        {:allow, _count} ->
          conn

        {:deny, _limit} ->
          conn
          |> put_status(:too_many_requests)
          |> put_resp_header("retry-after", "#{div(scale_ms, 1000)}")
          |> json(%{
            error: "Rate limit exceeded",
            message: "Too many requests. Please try again later.",
            retry_after_seconds: div(scale_ms, 1000)
          })
          |> halt()
      end
    end
  end

  # Get rate limit configuration based on endpoint type
  defp get_limits(:auth) do
    # Authentication: 20 attempts per minute (increased for shared IPs)
    {20, 60_000}
  end

  defp get_limits(:api) do
    # API endpoints: 120 requests per minute (increased for shared IPs)
    {120, 60_000}
  end

  defp get_limits(:llm) do
    # LLM endpoints: 30 requests per minute (more restrictive due to cost)
    {30, 60_000}
  end

  defp get_limits(_) do
    # Default: 30 requests per minute
    {30, 60_000}
  end

  # Get identifier for rate limiting (prefer user_id, fallback to IP)
  defp get_identifier(conn, _type) do
    case conn.assigns[:current_user] do
      %{id: user_id} when is_integer(user_id) ->
        "user:#{user_id}"

      _ ->
        # Use IP address as identifier
        ip = get_client_ip(conn)
        "ip:#{ip}"
    end
  end

  # Extract client IP address from connection
  defp get_client_ip(conn) do
    # Try to get real IP from x-forwarded-for header (for proxies/load balancers)
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        ip
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fallback to remote_ip
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          {a, b, c, d, e, f, g, h} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
          _ -> "unknown"
        end
    end
  end
end
