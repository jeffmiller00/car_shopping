require_relative 'fetch_base'


PER_PAGE = 100
BASE_URL = 'https://www.cars.com/shopping/results/'.freeze

def build_request_url(page=1)
  request = HTTPI::Request.new
  request.url = BASE_URL

    request.query = {
                    list_price_max: MAX_PRICE,
                    list_price_min: MIN_PRICE,
                    maximum_distance: 75,
                    page: page,
                    page_size: PER_PAGE,
                    sort: 'list_price_desc',
                    stock_type: 'all',
                    year_max: Date.today.year+1,
                    year_min: 2021,
                    zip: 60175
                  }
  MAKES.each do |make|
    request.query << "&makes[]=#{make}"
  end
  MODELS.each do |model|
    request.query << "&models[]=#{model}"
  end

  request.url.to_s
end



=begin
dealer_id=
keyword=
list_price_max=
list_price_min=
makes[]=kia
maximum_distance=75
mileage_max=
models[]=kia-telluride
monthly_payment=
page=1
page_size=100
sort=best_match_desc
stock_type=all
year_max=
year_min=
zip=60175
=end

browser = Watir::Browser.new :chrome, headless: true
browser.goto build_request_url

all_cars = JSON.parse(browser.elements(tag_name: 'cars-datalayer').first.text_content).first['vehicle_array']
total_results = browser.spans(class: 'total-filter-count').first.text_content.gsub(/\D/,'').to_i
pages = (total_results.to_f / PER_PAGE).ceil

=begin
{"trim"=>"S",
 "make"=>"Kia",
 "cat"=>"suv_midsize",
 "year"=>"2021",
 "customer_id"=>"6062832",
 "stock_type"=>"Used",
 "vin"=>"5XYP6DHC5MG134294",
 "seller_type"=>"dealership",
 "certified_preowned"=>false,
 "listing_id"=>"5c3f0822-d6f2-4952-b8e2-be302a1082a6",
 "mileage"=>"35997",
 "model"=>"Telluride",
 "sponsored"=>true,
 "nvi_program"=>false,
 "exterior_color"=>"Ebony Black",
 "fuel_type"=>"Gasoline",
 "msrp"=>"37500",
 "sponsored_type"=>"inventory_ad",
 "bodystyle"=>"SUV",
 "price"=>"33750",
 "cpo_indicator"=>false,
 "badges"=>["great_deal", "price_drop_in_cents"],
 "canonical_mmt"=>"Kia:Telluride:S",
 "stock_sub"=>""}
=end
ws = get_worksheet
pages.times do |n|
  all_cars.each do |car|
    vin  = car['vin']
    next if ws.rows.map{|row| row[11]}.include?(vin)

    year = car['year']
    make = car['make']
    model = car['model']

    # This isn't needed right now.
    # puts "---------- Interested? #{interested?(model)}"
    # next unless interested?(model)

    headline = "#{year} #{make} #{model} - #{car['trim']}"
    puts "---------- Evaluating: #{headline}"

    price = car['price'].to_i
    puts "---------- Price? #{price.between?(MIN_PRICE, MAX_PRICE)}"
    next unless price.between?(MIN_PRICE, MAX_PRICE)

    mileage = car['mileage'].to_i
    puts "---------- Miles? #{mileage > MAX_MILES}"
    next if mileage > MAX_MILES

    certified = car['certified_preowned'] ? 'Yes' : 'No'

    link = "https://www.cars.com/vehicledetail/#{car['listing_id']}/"
    more_info = car['badges'].any? ? "Specials: #{car['badges'].join(', ')}" : ''

    ws.insert_rows(ws.num_rows + 1, [[year,
                                      make,
                                      model,
                                      certified,
                                      price,
                                      mileage,
                                      car['trim'],
                                      car['msrp'],
                                      car['exterior_color'],
                                      headline,
                                      link,
                                      vin,
                                      Date.today.to_s,
                                      more_info]])
  end
  ws.save

  if n + 1 < pages
    puts '|---------------------------------------------------'
    puts "THERE ARE MORE! ~ Page #{n+1} of #{pages} complete. Moving to page #{n+2}"
    puts '|---------------------------------------------------'
    browser.goto build_request_url(n+2)
    all_cars = JSON.parse(browser.elements(tag_name: 'cars-datalayer').first.text_content).first['vehicle_array']
  end
end
