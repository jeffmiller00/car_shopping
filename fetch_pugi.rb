require_relative 'fetch_base'


worksheet = get_worksheet
URLS = ['http://www.pugimazda.com']

URLS.each do |url|
  base_url = url
  request = HTTPI::Request.new
  request.url = "#{base_url}/used-inventory/vehicles-for-sale-downers-grove.htm"
  request.query = { #
                    search: '',
                    year: '2015-',
                    make: 'Ford,Mazda',
                    bodyStyle: 'SUV',
                    odometer: "1-#{MAX_MILES}",
                    sortBy: 'year+desc'
                  }
  #browser = Watir::Browser.new :chrome, headless: true
  browser = Watir::Browser.new :phantomjs
  browser.goto request.url.to_s

  cars = []
  while cars.empty?
    full_doc = Nokogiri::HTML.parse(browser.html)
    cars = full_doc.xpath('//*[@id="compareForm"]/div/div[2]/ul/li')
    sleep(0.25)
  end

  count = full_doc.xpath('//*[@class="vehicle-count"]').text.to_i
  PAGES = (count * 1.0 / PER_PAGE).ceil

  PAGES.times do |n|
    cars.each do |car|
      headline = car.xpath(".//h3[contains(@class, 'fn')]/a").first.text.strip
      puts "---------- Evaluating: #{headline}"
      model = get_model(headline)
      puts "---------- Interested? #{interested?(model)}"
      next unless interested?(model)

      vin  = car.search("[text()*='Stock #']").first.next_element.text.strip
      unless worksheet.rows.map{|row| row[11]}.include?(vin)
        year = get_year(headline)
        make = get_make(headline)
        price = car.xpath(".//span[contains(@class, 'internetPrice')]").first.text.gsub(/\D/, "").to_i
        puts "---------- Price? #{price < MIN_PRICE || price > MAX_PRICE}"
        next if price < MIN_PRICE || price > MAX_PRICE

        mileage = car.search("[text()*='Mileage']").first.next_element.text.gsub(/\D/, "").to_i
        puts "---------- Miles? #{mileage > MAX_MILES}"
        next if mileage > MAX_MILES

        city_mpg, hwy_mpg = get_mpgs(car.search("[text()*='MPG Range']").first.next_element.text)
        if car.search("[text()*='Exterior']").first
          color = car.search("[text()*='Exterior']").first.next_element.text.gsub(',', "")
        end
        link = car.xpath(".//h3[contains(@class, 'fn')]/a").first[:href]
        link = "#{base_url}#{link}"
        cert_badge = car.xpath(".//li[contains(@class, 'certified')]")
        certified = 'Yes' unless cert_badge.empty?

        worksheet.insert_rows(worksheet.num_rows + 1, [[year, make, model, certified, price, mileage, city_mpg, hwy_mpg, color, headline, link, vin, '']])
        worksheet.save
      end
    end

    if n +1 < PAGES
      puts '|---------------------------------------------------'
      puts 'THERE ARE MORE!'
      puts '|---------------------------------------------------'
      # request = HTTPI::Request.new
      # request.url = "#{base_url}/Certified-Inventory"
      # request.query = { ModelGroup: 'X3',
      #                   SortDirection: 'Descending',
      #                   SortField: 3007,
      #                   PageSize:36,
      #                   Page: n+2
      #                 }
      # browser = Watir::Browser.new :phantomjs
      # browser.goto request.url.to_s

      # cars = []
      # while cars.empty?
      #   full_doc = Nokogiri::HTML.parse(browser.html)
      #   cars = full_doc.xpath("//*[@id=\"inventorySearchResultsContainer\"]/div/ul/li")
      #   sleep(0.25)
      # end
    end
  end
end

`brew services stop chromedriver`