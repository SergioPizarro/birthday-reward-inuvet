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
    # For test
    # today = Date.new(Date.today.year, 10, 31)
    today = Date.today
    # Loop through paginated users API until there are no more pages
    loop do
      users_response = HTTParty.get(url, headers: headers)
      users = users_response["_data"] || []
      # Process each user on the current page
      users.each do |user|
        # Only consider users with status 'ACTIVE'
        next unless user["status"] == "ACTIVE"
        # Find the custom attribute for date_of_birth
        birthday_attr = user["custom_attributes"]&.find { |attr| attr["id"] == "date_of_birth" }
        next unless birthday_attr && birthday_attr["value"].present?
        begin
          # Parse the birthday and check if it matches today
          bday = Date.parse(birthday_attr["value"])
          if bday.month == today.month && bday.day == today.day
            # Add user info to birthday_today if today is their birthday
            birthday_today << {
              email: user["email"],
              first_name: user["first_name"],
              last_name: user["last_name"],
              birthday: birthday_attr["value"]
            }
          end
        rescue ArgumentError
          # Skip users with invalid birthday values
          next
        end
      end
      # Check if there is a next page; if not, exit loop
      next_link = users_response.dig("_meta", "links", "next", "href")
      break unless next_link && !next_link.empty?
      url = next_link
    end

    # Output list of users whose birthday is today
    puts "Users whose birthday is today:"
    puts birthday_today.inspect
    # Send a birthday email to each user
    birthday_today.each do |user|
      BirthdayMailer.birthday_greeting(user).deliver_now
      puts "Sent birthday email to #{user[:email]}"
    end
    # Log the end of the task
    Rails.logger.info "[scheduler:send_birthday_rewards] finished at #{Time.current}"
  end
end
