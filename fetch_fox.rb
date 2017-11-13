require 'httpi'
require 'nokogiri'
require 'pry-coolline'
require 'google_drive'


MAKES = %w(Acura BMW Ford Honda Lincoln)
MODELS = %w(Edge RDX X3 MKC MKX)

def interested?(model)
  !model.nil?
end

def get_model(car_text)
  car_text.strip.split.find { |hay| MODELS.include?(hay)}
end

def get_year(car_text)
  year = car_text[/\d{4}/].to_i
  return year if year > 2000

  year = car_text[/\d{2}/]
  year.to_i + 2000
end

def get_make(car_text)
  car_text.strip.split.find { |hay| MAKES.include?(hay)}
end

def get_mpgs(mpg_txt)
  mpgs = mpg_txt.split('/')
  mpgs.each_with_index do |mpg, i|
    mpgs[i] = mpg.gsub(/\D/, "").to_i
  end
  mpgs
end


PER_PAGE = 35
# Authenticate a session with your Service Account
session = GoogleDrive::Session.from_service_account_key("client_secret.json")
spreadsheet = session.spreadsheet_by_title('Car Finder')
worksheet = spreadsheet.worksheets.first

BASE_URL = 'http://www.foxfordchicago.com'
request = HTTPI::Request.new
request.url = "#{BASE_URL}/used-inventory/index.htm"
request.query = { make: 'Acura,BMW,Ford,Honda,Lincoln',
                  odometer: '1-60000',
                  internetPrice: '14000-45000',
                  sortBy: 'year+desc',
                  start: 0
                }
response = HTTPI.get(request)
full_doc = Nokogiri::HTML(response.body)
count = full_doc.xpath("//span[contains(@class, 'vehicle-count')]").text.to_i
PAGES = (count * 1.0 / PER_PAGE).ceil

PAGES.times do |n|
  cars = full_doc.xpath('//*[@id="compareForm"]/div/div[2]/*/li')

  cars.each do |car|
    headline = car.xpath('div[1]/div/h3/a').first.text
    model = get_model(headline)
    next unless interested?(model)
    vin  = car.search("[text()*='VIN']").first.next_element.text
    unless worksheet.rows.map{|row| row[11]}.include?(vin)
      year = get_year(headline)
      make = get_make(headline)
      price = car.search("[text()*='Price']")[1].next_element.text.gsub(/\D/, "").to_i
      mileage = car.search("[text()*='Mileage']").first.next_element.text.gsub(/\D/, "").to_i
      city_mpg, hwy_mpg = get_mpgs(car.search("[text()*='EPA-Est MPG']").first.next_element.text)
      if car.search("[text()*='Exterior']").first
        color = car.search("[text()*='Exterior']").first.next_element.text.delete!(',') 
      else
        color = 'Unknown'
      end
      link = "#{BASE_URL}#{car.xpath('div[1]/div/h3/a').first[:href]}"

      worksheet.insert_rows(worksheet.num_rows + 1, [[year, make, model, '', price, mileage, city_mpg, hwy_mpg, color, headline, link, vin, '']])
      worksheet.save
    end
  end

  if n+1 < PAGES
    request = HTTPI::Request.new
    request.url = "#{BASE_URL}/used-inventory/index.htm"
    request.query = { make: 'Acura,BMW,Ford,Honda,Lincoln',
                      odometer: '1-60000',
                      internetPrice: '14000-45000',
                      sortBy: 'year+desc',
                      start: ((n+1)*PER_PAGE)
                    }
    response = HTTPI.get(request)
    full_doc = Nokogiri::HTML(response.body)
  end
end
