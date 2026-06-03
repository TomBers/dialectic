defmodule Dialectic.Mailer do
  use Swoosh.Mailer, otp_app: :dialectic

  def default_from do
    name = Application.get_env(:dialectic, :email_from_name, "RationalGrid")
    address = Application.get_env(:dialectic, :email_from_address, "no-reply@rationalgrid.ai")

    {name, address}
  end
end
