require_relative 'fetch_base'


worksheet = get_worksheet
PER_PAGE = 100
# https://www.cars.com/for-sale/searchresults.action/?bsId=20211&dealerType=all&mkId=20001,20049,20005,20017,20073,20028&mlgId=28869&page=1&perPage=100&prMn=15000&prMx=25000&rd=50&searchSource=GN_REFINEMENT&sort=price-highest&stkTypId=28881&yrId=56007,58487,30031936,35797618,36362520,36620293&zc=60175
URLS = ['https://www.cars.com/for-sale/searchresults.action/']

URLS.each do |url|
  base_url = url
  request = HTTPI::Request.new
  request.url = base_url

  request.query = {
                    dealerType: 'all',
                    mdId: '20788,21105,21087,21107,21422,22378,32885',
                    mkId: '20001,20005,20015,20073',
                    mlgId: 28870,
                    page:1,
                    perPage: PER_PAGE,
                    prMn: MIN_PRICE,
                    prMx: MAX_PRICE,
                    rd: 50,
                    sort: 'price-highest',
                    stkTypId: 28881,
                    yrId: '35797618,36362520,36620293',
                    zc: 60175,
                  }
  browser = Watir::Browser.new :chrome, headless: true
  browser.goto request.url.to_s
  all_cars = browser.execute_script('return CARS.digitalData')
  cars = all_cars['page']['vehicle']

  full_doc = Nokogiri::HTML.parse(browser.html)
  count = full_doc.xpath(".//span[contains(@class, 'filter-count')]").text.gsub(/\D/, "").to_i

  PAGES = (count * 1.0 / PER_PAGE).ceil


=begin
  {"bodyStyle"=>"Sedan",
   "certified"=>false,
   "customerId"=>5381876,
   "detail"=>"searchResults",
   "listingId"=>775767104,
   "make"=>"Acura",
   "makeId"=>20001,
   "mileage"=>5997,
   "model"=>"ILX",
   "modelId"=>47843,
   "price"=>25000,
   "priceBadge"=>"Good Deal",
   "privateSeller"=>false,
   "seller"=>
    {"city"=>"Libertyville",
     "customerId"=>5381876,
     "dealerChatProvider"=>nil,
     "distanceFromSearchZip"=>30,
     "formattedPhoneNumber"=>"(888) 820-2207",
     "formattedPhoneNumber2"=>nil,
     "hasCpoShowroomEnabled"=>true,
     "id"=>45331765,
     "name"=>"McGrath Acura of Libertyville",
     "phoneNumber"=>"8888202207",
     "phoneNumber2"=>nil,
     "rating"=>4.8,
     "reviewCount"=>"21",
     "sellerDisplayLabel"=>"Dealer",
     "state"=>"IL",
     "streetAddress"=>"1620 S Milwaukee Ave",
     "truncatedDescription"=>"2018 Acura ILX Technology Package Bellanova White Pearl FWD 2.4L I4 DO..."},
   "stockType"=>"Used",
   "trim"=>"Technology Plus Package",
   "type"=>"inventory",
   "vin"=>"19UDE2F7XJA007568",
   "year"=>2018}
=end
  PAGES.times do |n|
    cars.each do |car|
      vin  = car['vin']
      next if worksheet.rows.map{|row| row[11]}.include?(vin)

      year = car['year']
      make = car['make']
      model = car['model']
      puts "---------- Interested? #{interested?(model)}"
      next unless interested?(model)

      headline = car['seller']['truncatedDescription'].gsub('...','') || "#{year} #{make} #{model} - #{car['trim']}"
      puts "---------- Evaluating: #{headline}"

      price = car['price'].to_i
      puts "---------- Price? #{price < MIN_PRICE || price > MAX_PRICE}"
      next if price < MIN_PRICE || price > MAX_PRICE

      mileage = car['mileage'].to_i
      puts "---------- Miles? #{mileage > MAX_MILES}"
      next if mileage > MAX_MILES

      # car.search("[text()*='EPA-Est MPG']")
      # city_mpg, hwy_mpg = get_mpgs(car.search("[text()*='EPA-Est MPG']").first.next_element.text)
      # if car.search("[text()*='Ext. Color']").first.parent.text.gsub('Ext. Color:','').strip
      #   color = car.search("[text()*='Ext. Color']").first.parent.text.gsub('Ext. Color:','').strip
      # end
      city_mpg, hwy_mpg, color = ['', '', '']

      link = "https://www.cars.com/vehicledetail/detail/#{car['listingId']}/overview/"
      certified = car['certified'] ? 'Yes' : 'No'
      more_info = car['trim']

      worksheet.insert_rows(worksheet.num_rows + 1, [[year, make, model, certified, price, mileage, city_mpg, hwy_mpg, color, headline, link, vin, Date.today.to_s, more_info]])
      worksheet.save
    end

# binding.pry
    if n + 1 < PAGES
      puts '|---------------------------------------------------'
      puts 'THERE ARE MORE!'
      puts '|---------------------------------------------------'
      request.url = base_url
      request.query = {
                        dealerType: 'all',
                        mdId: '20788,21105,21087,21107,21422',
                        mkId: '20001,20015,20073',
                        mlgId: 28870,
                        page:1,
                        perPage: PER_PAGE,
                        prMn: 20000,
                        prMx: 60000,
                        rd: 50,
                        sort: 'price-highest',
                        stkTypId: 28881,
                        yrId: '35797618,36362520,36620293',
                        zc: 60175,
                      }
      browser = Watir::Browser.new :chrome, headless: true
      browser.goto request.url.to_s
      all_cars = browser.execute_script('return CARS.digitalData')
      cars = all_cars['page']['vehicle']
    end
  end
end

# brew services stop chromedriver