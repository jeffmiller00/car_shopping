require_relative 'fetch_base'


PER_PAGE = 100
BASE_URL = 'https://www.cars.com/shopping/results/'.freeze

=begin
include_shippable=
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
    year_min: MIN_YEAR,
    zip: 60175,
    include_shippable: true,
  }
  MAKES.each do |make|
    request.query << "&makes[]=#{make}"
  end
  MODELS.each do |model|
    request.query << "&models[]=#{model}"
  end

  request.url.to_s
end



response = Typhoeus.post(
  "https://api.zyte.com/v1/extract",
  userpwd: ENV['ZYTE_API_KEY'],
  headers: { "Content-Type" => "application/json" },
  body: {
    url: build_request_url,
    httpResponseBody: true,
    followRedirect: true
  }.to_json
)

binding.pry if response.code != 200 || response.body.nil? || response.body.strip.empty?
raw_html = Base64.decode64(JSON.parse(response.body)['httpResponseBody'])
doc = Nokogiri::HTML(raw_html)

all_cars = JSON.parse(doc.at_css("cars-datalayer").text.strip).first['vehicle_array']
total_results = doc.at_css("span.total-filter-count").text.gsub(/\D/,'').to_i
pages = (total_results.to_f / PER_PAGE).ceil

=begin
"listing_id" => "fe5f5873-12bc-42ea-a522-9fb3f1077617",
"vertical_position" => 1,
"cpo_indicator" => false,
"stock_sub" => "",
"canonical_mmty" => "Ford:F-150:STX:2025",
"model" => "F-150",
"price" => "49840",
"trim" => "STX",
"dealer_name" => "Harvard Ford",
"customer_id" => "6000759",
"nvi_program" => false,
"vin" => "1FTEW2LP8SFA38844",
"cat" => "truck_fullsize",
"badges" => ["american_made_index_ranking"],
"mileage" => "22",
"seller_type" => "dealership",
"stock_type" => "New",
"year" => "2025",
"msrp" => "55095",
"fuel_type" => "Gasoline",
"certified_preowned" => false,
"canonical_mmt" => "Ford:F-150:STX",
"drivetrain" => "Four-wheel Drive",
"interior_color" => "Black/Bronze",
"sponsored_type" => "inventory_ad",
"relevancy_score" => nil,
"sponsored" => true,
"dealer_zip" => "60033",
"bodystyle" => "Truck",
"make" => "Ford",
"exterior_color" => "Iconic Silver Metallic",
"photo_count" => 25,
"cpo_package" => nil},
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

    car['back_cam'] = 'Unknown'

    ws.insert_rows(ws.num_rows + 1, [[year,
                                      make,
                                      model,
                                      certified,
                                      price,
                                      mileage,
                                      car['trim'],
                                      car['back_cam'],
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
    response = Typhoeus.post(
      "https://api.zyte.com/v1/extract",
      userpwd: ENV['ZYTE_API_KEY'],
      headers: { "Content-Type" => "application/json" },
      body: {
        url: build_request_url(n+2),
        httpResponseBody: true,
        followRedirect: true
      }.to_json
    )

    binding.pry if response.code != 200 || response.body.nil? || response.body.strip.empty?
    raw_html = Base64.decode64(JSON.parse(response.body)['httpResponseBody'])
    doc = Nokogiri::HTML(raw_html)

    all_cars = JSON.parse(doc.at_css("cars-datalayer").text.strip).first['vehicle_array']
  end
end
