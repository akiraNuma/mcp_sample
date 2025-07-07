require 'net/http'
require 'json'
require 'uri'

# 天気情報を取得するツール
class WeatherTool < MCP::Tool
  description "指定した都市の現在の天気を取得します"
  input_schema(
    properties: {
      city: {
        type: "string",
        description: "都市名（例：Tokyo, Osaka, Kyoto）"
      }
    },
    required: ["city"]
  )

  class << self
    def call(city:)
      weather_data = get_current_weather(city)
      MCP::Tool::Response.new([{
        type: "text",
        text: weather_data
      }])
    end

    private

    def get_current_weather(city)
      # OpenWeatherMap API（無料版）を使用
      # 実際のAPIキーが必要な場合は環境変数から取得
      api_key = ENV['OPENWEATHER_API_KEY'] || 'demo_key'

      begin
        uri = URI("http://api.openweathermap.org/data/2.5/weather")
        params = {
          q: city,
          appid: api_key,
          units: 'metric',
          lang: 'ja'
        }
        uri.query = URI.encode_www_form(params)

        response = Net::HTTP.get_response(uri)

        if response.code == '200'
          data = JSON.parse(response.body)
          format_weather_data(data)
        elsif response.code == '401'
          # APIキーが無効な場合はモックデータを返す
          get_mock_weather_data(city)
        else
          error_data = JSON.parse(response.body) rescue {}
          "エラー: #{error_data['message'] || 'Unknown error'}"
        end
      rescue => e
        # ネットワークエラーやその他の問題の場合はモックデータを返す
        get_mock_weather_data(city)
      end
    end

    def format_weather_data(data)
      weather_info = {
        city: data['name'],
        country: data['sys']['country'],
        temperature: "#{data['main']['temp']}°C",
        feels_like: "#{data['main']['feels_like']}°C",
        humidity: "#{data['main']['humidity']}%",
        pressure: "#{data['main']['pressure']} hPa",
        description: data['weather'][0]['description'],
        wind_speed: "#{data['wind']['speed']} m/s",
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }

      JSON.pretty_generate(weather_info)
    end

    def get_mock_weather_data(city)
      # モックデータ（APIキーがない場合やテスト用）
      mock_data = {
        city: city,
        country: 'JP',
        temperature: "#{15 + rand(20)}°C",
        feels_like: "#{17 + rand(20)}°C",
        humidity: "#{40 + rand(40)}%",
        pressure: "#{1000 + rand(50)} hPa",
        description: ['晴れ', '曇り', '小雨', '快晴'][rand(4)],
        wind_speed: "#{rand(10)} m/s",
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        note: "これはモックデータです（APIキーが設定されていません）"
      }

      JSON.pretty_generate(mock_data)
    end
  end
end
