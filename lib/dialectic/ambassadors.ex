defmodule Dialectic.Ambassadors do
  alias Dialectic.Ambassadors.Interest
  require Logger

  @form_url "https://docs.google.com/forms/d/e/1FAIpQLSeaHiT23pysqcWf97DePI1KgkRWyq13nFettY0CfFsoZAQf5w/formResponse"

  def change_interest(attrs \\ %{}) do
    Interest.changeset(%Interest{}, attrs)
  end

  def configured? do
    opts = form_options()

    valid_option?(
      opts[:form_url],
      ~r|^https://docs\.google\.com/forms/d/(?:e/)?[A-Za-z0-9_-]+/formResponse$|
    ) and
      valid_option?(opts[:email_entry], ~r/^entry\.\d+$/) and
      valid_option?(opts[:role_entry], ~r/^entry\.\d+$/) and
      opts[:email_entry] != opts[:role_entry]
  end

  def register_interest(attrs) do
    with {:ok, interest} <- attrs |> change_interest() |> Ecto.Changeset.apply_action(:insert) do
      if configured?() do
        submit(interest, form_options())
      else
        {:error, :not_configured}
      end
    end
  end

  defp submit(interest, opts) do
    request =
      Req.new(
        url: opts[:form_url],
        form: [{opts[:email_entry], interest.email} | role_fields(interest, opts[:role_entry])],
        redirect: false,
        retry: false,
        receive_timeout: 5_000,
        connect_options: [timeout: 5_000]
      )

    request = if opts[:req_plug], do: Req.merge(request, plug: opts[:req_plug]), else: request

    case Req.post(request) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, :submitted}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Ambassador Google Form submission failed", status: status)
        {:error, :submission_failed}

      {:error, _reason} ->
        Logger.warning("Ambassador Google Form request failed")
        {:error, :submission_failed}
    end
  end

  defp role_fields(%Interest{role: :other, other_role: description}, entry) do
    [{entry, "__other_option__"}, {entry <> ".other_option_response", description}]
  end

  defp role_fields(interest, entry) do
    [{entry, interest.role |> Atom.to_string() |> String.capitalize()}]
  end

  defp form_options do
    defaults = [
      form_url: System.get_env("AMBASSADOR_GOOGLE_FORM_URL") || @form_url,
      email_entry: System.get_env("AMBASSADOR_GOOGLE_FORM_EMAIL_ENTRY") || "entry.2038688135",
      role_entry: System.get_env("AMBASSADOR_GOOGLE_FORM_ROLE_ENTRY") || "entry.1916744247"
    ]

    Keyword.merge(defaults, Application.get_env(:dialectic, __MODULE__, []))
  end

  defp valid_option?(value, pattern) when is_binary(value), do: Regex.match?(pattern, value)
  defp valid_option?(_value, _pattern), do: false
end
