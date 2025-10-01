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
    response = HTTParty.post(url, headers: headers, body: URI.encode_www_form(body))
    puts "Response Auth"
    puts response.body
    # Auth end

    
    Rails.logger.info "[scheduler:send_birthday_rewards] finished at #{Time.current}"

  end
end
