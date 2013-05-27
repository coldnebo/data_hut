
# run from the samples dir with: 
# $ rake samples
# $ ruby league_of_legends.rb 
# then
# $ ruby lol_lore_relationships

require_relative 'common/sample_helper.rb'

require 'data_hut'
require 'pry'
require 'json'
require 'highline/import'
require 'nokogiri'
require 'open-uri'

# helper method to highlight and underline relations and places in the lore text
def highlight(text,relations,places)
  highlight = String.new(text)
  relations.each do |relation|
    highlight.gsub!(/(#{relation["name"]})/) {"\033[7m#{$1}\033[0m"}
  end
  places.each do |place|
    highlight.gsub!(/(#{place})/) {"\033[4m#{$1}\033[0m"}
  end

  highlight
end



raise "don't forget to run 'league_of_legends' sample first!" unless File.exists?("lolstats.db")
dh = DataHut.connect("lolstats")
ds = dh.dataset

# get the places of origin if they haven't already been loaded.
places_of_origin = dh.fetch_meta(:places_of_origin)
if places_of_origin.nil?
  doc = Nokogiri::HTML(open("http://leagueoflegends.wikia.com/wiki/Category:Places"))
  all_places = doc.css('div#mw-pages a').collect {|n| n.text}
  doc = Nokogiri::HTML(open("http://leagueoflegends.wikia.com/wiki/Category:Fields_of_Justice"))
  fields_of_justice = doc.css('div#mw-pages a').collect {|n| n.text}
  places_of_origin = all_places - fields_of_justice - ["The League of Legends"]
  dh.store_meta(:places_of_origin, places_of_origin)
end

# collect the champion names from the existing data.
names = ds.collect{|r|r.name}

# now, for each champion record in the data, add a set of relationships to other champions and a flag
# indicating whether these relationships have been reviewed or not.
dh.transform do |r|
  # we'll search the single works and word pairs for the names (since some names have a space)
  lore_words = r.lore.split(/\s+|\b/)
  lore_pairs = []
  lore_words.each_cons(2){|s| lore_pairs.push s.join(' ')}
  # for the champions with single names, try to match, no?
  relations = names & lore_words
  # now match any with spaces in their names by matching against pairings. (we'll get them this time!)
  relations.concat((names & lore_pairs))
  relations = relations.reject{|d| d == r.name} # don't include ourself in the relations if mentioned.
  relations = relations.collect{|d| {name:d}}
  # does this motivate storing blobs?  No, and I'll tell you why: https://github.com/coldnebo/data_hut/wiki/not-everything-can-be-a-blob
  r.relations = relations.to_json.to_s  
  r.reviewed_relations = false
end

# now grab all the non-empty relations and display them for consideration...
non_empty_relations = ds.reject{|r| r.relations == "[]"}

puts "current non-empty champion relations:"
non_empty_relations.each do |r|
  puts "#{r.name}: #{r.relations}"
end


# identifying the relationships automatically is a little too complex even with AI, so 
# instead, we'll opt for manual review...
non_empty_relations.each do |r|
  next if r.reviewed_relations
  relations = JSON.parse(r.relations)
  puts "--------------------------------"
  puts "Champion: #{r.name}"
  puts "Lore: "
  puts highlight(r.lore, relations, places_of_origin)
  puts "\nBased on your reading of the lore above, how would you classify #{r.name}'s relationships?"
  r.reviewed_relations = true
  relations.each do |relation|
    relation['type'] = ask( "#{relation['name']} is #{r.name}'s: " )
    if relation['type'].empty?
      r.reviewed_relations = false
    end
  end
  r.relations = relations.to_json.to_s
  r.save_changes
  break unless agree("continue? (y|n)", true)
end

#binding.pry

puts "done."