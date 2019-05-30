require 'telegram/bot'

class TelegramAlertsJob < ApplicationJob
  queue_as :telegram

  def perform(detection_id)
    return unless Settings.telegram_enabled

    @detection = Messenger::DetectionPresenter.new Detection.includes(:camera, person: :shared_list).find_by(id: detection_id)
    return unless @detection&.notifiable

    channel_id = @detection.camera&.telegram_channel_id
    return if channel_id.blank?

    token = Settings.telegram_key
    Telegram::Bot::Client.run(token) do |bot|
      kb = [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: 'yes'),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: 'no')
      ]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

      bot.api.send_photo(chat_id: channel_id,
                         photo: Faraday::UploadIO.new(@detection.alert_merged_photo_path, 'image/jpeg'),
                         caption: detection_caption,
                         reply_markup: markup)

      bot.listen do |message|
        case message
          when Telegram::Bot::Types::CallbackQuery
            if message.data == 'yes'
              kb = [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: 'yes'),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: 'no')
              ]
              markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
              
              bot.api.edit_message_reply_markup(chat_id: message.from.id, message_id: message.message_id, reply_markup: markup)
            elsif message.data == 'no'
              kb = [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да ', callback_data: 'yes'),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет ', callback_data: 'no')
              ]
              markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
              
              bot.api.edit_message_reply_markup(chat_id: message.from.id, message_id: message.message_id, reply_markup: markup)
            end
          end
      end
    end
  end

  def detection_caption
    "#{@detection.alert_tags}\n🕵🏻‍♂️ #{@detection.alert_message}"
  end
end
