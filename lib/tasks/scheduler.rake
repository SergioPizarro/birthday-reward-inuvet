require 'date'

namespace :scheduler do
  desc "Send birthday rewards to users"
  task send_birthday_rewards: :environment do
    # Log the start of the task
    Rails.logger.info "[scheduler:send_birthday_rewards] started at #{Time.current}"

    # === 1. Authenticate with Personio API ===
    # Prepare the authentication request to get an access token
    url = 'https://api.personio.de/v2/auth/token'
    headers = {
      'accept' => 'application/json',
    }
    body = {
      grant_type: 'client_credentials',
      client_id: ENV['PERSONIO_CLIENT_ID'],
      client_secret: ENV['PERSONIO_CLIENT_SECRET']
    }
    # Send the POST request to get the access token
    auth_response = HTTParty.post(url, headers: headers, body: URI.encode_www_form(body))
    puts "Response Auth"
    puts auth_response.body
    # === End authentication ===

    # === 2. Fetch and process users ===
    # Start with the first page of users
    url = 'https://api.personio.de/v2/persons?limit=50'
    headers = {
      'accept' => 'application/json',
      'Authorization' => "Bearer #{auth_response['access_token']}"
    }
    birthday_today = []
    today = Date.today
    #FORTESTING=>  today = Date.new(Date.today.year, 10, 31)

    loop do
      users_response = HTTParty.get(url, headers: headers)
      users = users_response["_data"] || []
      users.each do |user|
        next unless user["status"] == "ACTIVE"
        birthday_attr = user["custom_attributes"]&.find { |attr| attr["id"] == "date_of_birth" }
        next unless birthday_attr && birthday_attr["value"].present?
        send_birthday_rewards_attr = user["custom_attributes"]&.find { |attr| attr["global_id"] == "17307786"}
        next unless send_birthday_rewards_attr && send_birthday_rewards_attr["value"] == "Ja"
        begin
          bday = Date.parse(birthday_attr["value"])
          if bday.month == today.month && bday.day == today.day
            birthday_today << {
              email: user["email"],
              first_name: user["first_name"],
              last_name: user["last_name"],
              birthday: birthday_attr["value"],
              send_birthday_rewards: send_birthday_rewards_attr["value"]
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
    if birthday_today.present?
      puts "----------------------"
      puts "Today is: #{today}"
      birthday_today.each do |user|
        BirthdayMailer.birthday_greeting(user).deliver_now
        puts "Sent birthday email to #{user[:email]}"
      end
      puts "----------------------"
    else
      puts "----------------------"
      puts "No users found whose birthday is: #{today}"
      puts "----------------------"
    end
    Rails.logger.info "[scheduler:send_birthday_rewards] finished at #{Time.current}"
  end


end
