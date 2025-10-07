class BirthdayMailer < ApplicationMailer
  default from: ENV["GMAIL_SENDER_EMAIL"]

  def birthday_greeting(user)
    @user = user
    mail(to: @user[:email], subject: "Happy Birthday from Inuvet!")
  end
end
