
# run from the samples dir with: 
# $ rake samples
# $ ruby weather_station.rb 

# or every 10 minutes with:
# $ yes "ruby weather_station.rb; sleep 600"|sh

require_relative 'sample_helper.rb'

require 'data_hut'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'haml'
require 'json'


def generate_report(ds)
  @data = ds.order(:start_time).collect{|d| d.to_hash}.to_json
  @data = %{ var data = #{@data}; }
  @style = File.read("weather_files/weather.css")
  @app = File.read("weather_files/weather.js")
  engine = Haml::Engine.new(File.read("weather_files/report.html.haml"))
  report_name = "weather_report.html"
  File.open(report_name, "w") do |f|
    f.puts engine.render(self)
  end
  puts "rendered '#{report_name}'. open in your favorite browser."
end


# boston weather
url = 'http://forecast.weather.gov/MapClick.php?lat=42.35843&lon=-71.0597732&unit=0&lg=english&FcstType=dwml'

doc = Nokogiri::HTML(open(url))

current_observations = doc.xpath('//data[@type="current observations"]').first

dh = DataHut.connect("weather")

puts "getting current observation:"
# since the parallel arrays need to be assembled, we'll need to iterate over an index in this case...
dh.extract((0..1)) do |r, i|
  r.start_time = DateTime.parse(current_observations.xpath('//time-layout/start-valid-time[@period-name="current"]').text)
  r.temperature = current_observations.xpath('//temperature[@type="apparent"]').text.to_f
  r.dew_point = current_observations.xpath('//temperature[@type="dew point"]').text.to_f
  r.wind_speed_kts = current_observations.xpath('//wind-speed[@type="sustained"]').text.to_f
end

dh.transform do |r|
  r.wind_speed_mph = r.wind_speed_kts * 1.15
  # from http://en.wikipedia.org/wiki/Wind_chill
  r.wind_chill = 35.74 + 0.6215*r.temperature - 35.75*(r.wind_speed_mph**0.16) + 0.4275*r.temperature*(r.wind_speed_mph**0.16)
  puts "  read a value last updated at #{r.start_time}."
end

dh.transform_complete
puts "done."

ds = dh.dataset

generate_report(ds)

#binding.pry

puts "run weather_station.rb again in a few minutes to record more data."
