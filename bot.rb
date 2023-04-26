require 'telegram/bot'
require 'dvb'

token = 'REPLACE_ME'

def response_text(departures)
  departures.map do |departure|
    "#{format('%02d', departure.relative_time)}m Linie #{departure.line} - #{departure.direction}"
  end.join("\n")
end

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|

    if message.text != nil
      puts "[#{DateTime.now.strftime("%Y-%m-%d %H:%S")}] Query: #{message.from.first_name} #{message.from.last_name} for '#{message.text}'"

      if message.text == '/start'
        # Welcome message
        bot.api.send_message(chat_id: message.chat.id, text: "Willkommen beim DVB-Mini-Bot\nSchreibe mir irgendeine Haltestelle und ich gebe Dir dazu aktuelle Infos. 😊")
      else
        # Station Information
        begin
          station = DVB.find(message.text).first
          departures = DVB.monitor(message.text, 0, 10)
          if station.nil?
            bot.api.send_message(chat_id: message.chat.id, text: response_text(departures))
          else
            bot.api.send_message(chat_id: message.chat.id, text: "Haltestelle #{station.name}\n\n#{response_text(departures)}")
          end
        rescue RestClient::ServiceUnavailable
          bot.api.send_message(chat_id: message.chat.id, text: 'Fehler: Das konnte ich nicht verarbeiten.')
        rescue RestClient::NotFound
          bot.api.send_message(chat_id: message.chat.id, text: 'Fehler: Diese Haltestelle konnte ich nicht finden.')
        end
      end
    elsif message.location&.latitude && message.location&.longitude
      puts "[#{DateTime.now.strftime("%Y-%m-%d %H:%S")}] Query: #{message.from.first_name} #{message.from.last_name} for '#{message.location.latitude}, #{message.location.longitude}'"

      # Geocoding information
      stops = DVB.find_near(message.location.latitude , message.location.longitude)
      if stops.any?
        bot.api.send_message(chat_id: message.chat.id, text: "Am Standort befinden sich folgende Haltestellen:\n\n#{stops.map(&:name).join("\n")}")
        departures = DVB.monitor(stops.first.name, 0, 10)
        bot.api.send_message(chat_id: message.chat.id, text: "Haltestelle #{stops.first.name}\n\n#{response_text(departures)}")
      else
        bot.api.send_message(chat_id: message.chat.id, text: 'Ich konnte am Standort leider keine Haltestellen finden.')
      end
    end

  end
end
