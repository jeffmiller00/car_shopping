require 'httpi'
require 'nokogiri'
require 'watir'
require 'pry'
require 'google_drive'


MAKES = %w(kia honda hyundai toyota volkswagen)
MODELS = %w(kia-carnival kia-telluride honda-odyssey honda-pilot hyundai-palisade toyota-highlander toyota-highlander_hybrid toyota-sienna volkswagen-atlas)
MAX_MILES = 25000
MIN_PRICE = 30000
MAX_PRICE = 55000
# PER_PAGE = 36


def interested?(model)
  !model.nil?
end

def get_model(car_text)
  car_text.gsub('CX 9','CX-9').split.find { |hay| MODELS.include?(hay)}
end

def get_year(car_text)
  year = car_text[/\d{4}/].to_i
  return year if year > 2000

  year = car_text[/\d{2}/]
  year.to_i + 2000
end

def get_make_from_model(model)
  makes = {
    'MDX' => 'Acura',
    'Explorer' => 'Ford',
    'CX-9' => 'Mazda',
    'X5' => 'BMW',
  }
  makes[model.downcase] || 'Unknown'
end

def get_make(car_text)
  make = car_text.strip.split.find { |hay| MAKES.include?(hay)}
  make ||= get_make_from_model(get_model(car_text))
  make
end

def get_mpgs(mpg_txt)
  mpgs = mpg_txt.split('/')
  mpgs.each_with_index do |mpg, i|
    mpgs[i] = mpg.gsub(/\D/, "").to_i
  end
  mpgs
end

def get_worksheet
  # Authenticate a session with your Service Account
  session = GoogleDrive::Session.from_service_account_key("client_secret.json")
  spreadsheet = session.spreadsheet_by_title('Car Finder')
  worksheet = spreadsheet.worksheets.first
  worksheet
end