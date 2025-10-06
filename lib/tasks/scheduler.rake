require 'date'
namespace :scheduler do
  desc "Send birthday rewards to users"
  task send_birthday_rewards: :environment do
    Rails.logger.info "[scheduler:send_birthday_rewards] started at #{Time.current}"
    # Auth start
    url = 'https://api.personio.de/v2/auth/token'
    headers = {
      'accept' => 'application/json',
    }
    body = {
      grant_type: 'client_credentials',
      client_id: ENV['PERSONIO_CLIENT_ID'],
      client_secret: ENV['PERSONIO_CLIENT_SECRET']
    }
    auth_response = HTTParty.post(url, headers: headers, body: URI.encode_www_form(body))
    puts "Response Auth"
    puts auth_response.body
    # Auth end

    # Get users start
    url = 'https://api.personio.de/v2/persons?limit=50'
    headers = {
      'accept' => 'application/json',
      'Authorization' => "Bearer #{auth_response['access_token']}"
    }
    birthday_today = []
    today = Date.today
    loop do
      users_response = HTTParty.get(url, headers: headers)
      users = users_response["_data"] || []
      users.each do |user|
        next unless user["status"] == "ACTIVE"
        birthday_attr = user["custom_attributes"]&.find { |attr| attr["id"] == "date_of_birth" }
        next unless birthday_attr && birthday_attr["value"].present?
        begin
          bday = Date.parse(birthday_attr["value"])
          if bday.month == today.month && bday.day == today.day
            birthday_today << {
              email: user["email"],
              first_name: user["first_name"],
              last_name: user["last_name"],
              birthday: birthday_attr["value"]
            }
          end
        rescue ArgumentError
          next
        end
      end
      next_link = users_response.dig("_meta", "links", "next", "href")
      break unless next_link && !next_link.empty?
      url = next_link
    end
    puts "Users whose birthday is today:"
    puts birthday_today.inspect
    # Here you can send emails to users in birthday_today
    Rails.logger.info "[scheduler:send_birthday_rewards] finished at #{Time.current}"
  end
end
