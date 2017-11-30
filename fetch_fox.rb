require_relative 'fetch_base'


worksheet = get_worksheet

SEARCH_CRITERIA = { make: MAKES.join(','),
                    odometer: "1-#{MAX_MILES}",
                    internetPrice: "#{MIN_PRICE}-#{MAX_PRICE}",
                    sortBy: 'year+desc'
                  }

BASE_URL = 'http://www.foxfordchicago.com'
request = HTTPI::Request.new
request.url = "#{BASE_URL}/used-inventory/index.htm"
request.query = SEARCH_CRITERIA.merge!(start: 0)
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
      next if price < MIN_PRICE || price > MAX_PRICE

      mileage = car.search("[text()*='Mileage']").first.next_element.text.gsub(/\D/, "").to_i
      next if mileage > MAX_MILES

      city_mpg, hwy_mpg = get_mpgs(car.search("[text()*='EPA-Est MPG']").first.next_element.text)
      if car.search("[text()*='Exterior']").first
        color = car.search("[text()*='Exterior']").first.next_element.text.delete!(',')
      else
        color = 'Unknown'
      end
      link = "#{BASE_URL}#{car.xpath('div[1]/div/h3/a').first[:href]}"

      worksheet.insert_rows(worksheet.num_rows + 1, [[year, make, model, '', price, mileage, city_mpg, hwy_mpg, color, headline, link, vin, '']])
    end
  end
  worksheet.save

  if n+1 < PAGES
    request = HTTPI::Request.new
    request.url = "#{BASE_URL}/used-inventory/index.htm"
    request.query = SEARCH_CRITERIA.merge!(start: ((n+1)*PER_PAGE).to_i)
    response = HTTPI.get(request)
    full_doc = Nokogiri::HTML(response.body)
  end
end

`brew services stop chromedriver`