require 'httpi'
require 'nokogiri'
require 'watir'
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


PER_PAGE = 36
# Authenticate a session with your Service Account
session = GoogleDrive::Session.from_service_account_key("client_secret.json")
spreadsheet = session.spreadsheet_by_title('Car Finder')
worksheet = spreadsheet.worksheets.first

BASE_URL = 'https://perillobmw.com'
request = HTTPI::Request.new
request.url = "#{BASE_URL}/Used-BMW-Inventory"
request.query = { ModelGroup: 'X3',
                  SortDirection: 'Descending',
                  SortField: 3007,
                  PageSize:36,
                  Page: 1
                }
browser = Watir::Browser.new :phantomjs
browser.goto request.url.to_s

cars = []
while cars.empty?
  full_doc = Nokogiri::HTML.parse(browser.html)
  cars = full_doc.xpath("//*[@id=\"inventorySearchResultsContainer\"]/div/ul/li")
  sleep(0.25)
end

count = full_doc.xpath("//*[@id=\"inventorySearchResultsContainer\"]/div/div[1]/div[1]/span").text.to_i        
PAGES = (count * 1.0 / PER_PAGE).ceil

PAGES.times do |n|
  cars.each do |car|
    headline = car.xpath(".//div[contains(@class, 'inventoryListVehicleTitle')]/a/span").first.text.strip
    model = get_model(headline)
    next unless interested?(model)
    vin  = car.search("[text()*='VIN']").first.next_element.text.strip
    unless worksheet.rows.map{|row| row[11]}.include?(vin)
      year = get_year(headline)
      make = get_make(headline)
      price = car.xpath(".//span[contains(@class, 'vehiclePriceDisplay')]").first.text.gsub(/\D/, "").to_i
      next if price > 45000 || price < 10000
      mileage = car.search("[text()*='Mileage']").first.next_element.text.gsub(/\D/, "").to_i
      #city_mpg, hwy_mpg = get_mpgs(car.search("[text()*='EPA-Est MPG']").first.next_element.text)
      city_mpg, hwy_mpg = [nil, nil]
      if car.search("[text()*='Exterior']").first
        color = car.search("[text()*='Exterior']").first.next_element.text
      end
      link = car.xpath(".//div[contains(@class, 'inventoryListVehicleTitle')]/a").first[:href]
      certified = 'Yes' if request.url.to_s.include?('Certified')
      worksheet.insert_rows(worksheet.num_rows + 1, [[year, make, model, certified, price, mileage, city_mpg, hwy_mpg, color, headline, link, vin, '']])
      worksheet.save
    end
  end

  if n+1 < PAGES
    request = HTTPI::Request.new
    request.url = "#{BASE_URL}/Used-BMW-Inventory"
    request.query = { ModelGroup: 'X3',
                      SortDirection: 'Descending',
                      SortField: 3007,
                      PageSize:36,
                      Page: n+2
                    }
    browser = Watir::Browser.new :phantomjs
    browser.goto request.url.to_s

    cars = []
    while cars.empty?
      full_doc = Nokogiri::HTML.parse(browser.html)
      cars = full_doc.xpath("//*[@id=\"inventorySearchResultsContainer\"]/div/ul/li")
      sleep(0.25)
    end
  end
end
