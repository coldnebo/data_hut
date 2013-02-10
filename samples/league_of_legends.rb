
# run from the samples dir with: 
# $ ruby league_of_legends.rb 

require_relative 'sample_helper.rb'

require 'data_hut'
require 'nokogiri'
require 'open-uri'
require 'pry'

root = 'http://na.leagueoflegends.com'

# load the data once... (manually delete it to refresh)
unless File.exists?("lolstats.db")
  dh = DataHut.connect("lolstats")

  champions_page = Nokogiri::HTML(open("#{root}/champions"))

  urls = champions_page.css('table.champion_item td.description span a').collect{|e| e.attribute('href').value}

  # keep the powers for later since they are on different pages.
  powers = {}
  champions_page.css('table.champion_item').each do |c|
    name        = c.css('td.description span.highlight a').text
    attack      = c.css('td.graphing td.filled_attack').count
    health      = c.css('td.graphing td.filled_health').count
    spells      = c.css('td.graphing td.filled_spells').count
    difficulty  = c.css('td.graphing td.filled_difficulty').count
    powers.store(name, {attack_power: attack, defense_power: health, ability_power: spells, difficulty: difficulty})
  end

  puts "loading champion data"
  dh.extract(urls) do |r, url|
    champion_page = Nokogiri::HTML(open("#{root}#{url}"))
    r.name = champion_page.css('div.page_header_text').text

    st = champion_page.css('table.stats_table')
    names = st.css('td.stats_name').collect{|e| e.text.strip}
    values = st.css('td.stats_value').collect{|e| e.text.strip}
    modifiers = st.css('td.stats_modifier').collect{|e| e.text.strip}

    (0..names.count-1).collect do |i| 
      stat = (names[i].downcase.gsub(/ /,'_') << "=").to_sym
      r.send(stat, values[i].to_f)
      stat_per_level = (names[i].downcase.gsub(/ /,'_') << "_per_level=").to_sym
      per_level_value = modifiers[i].match(/\+([\d\.]+)/)[1].to_f rescue 0
      r.send(stat_per_level, per_level_value)
    end

    # add the powers for this champion...
    power = powers[r.name]
    r.attack_power = power[:attack_power]
    r.defense_power = power[:defense_power]
    r.ability_power = power[:ability_power]
    r.difficulty = power[:difficulty]

    print "."
  end
  puts "done."
end

dh = DataHut.connect("lolstats")

puts "first transform"
dh.transform do |r|
  r.total_damage = r.damage + (r.damage_per_level * 18.0)
  r.total_health = r.health + (r.health_per_level * 18.0)
  r.total_mana = r.mana + (r.mana_per_level * 18.0)
  r.total_move_speed = r.move_speed + (r.move_speed_per_level * 18.0)
  r.total_armor = r.armor + (r.armor_per_level * 18.0)
  r.total_spell_block = r.spell_block + (r.spell_block_per_level * 18.0)
  r.total_health_regen = r.health_regen + (r.health_regen_per_level * 18.0)
  r.total_mana_regen = r.mana_regen + (r.mana_regen_per_level * 18.0)
  print '.'
end

puts "second transform"
# there's no need to do transforms all in one batch either... you can layer them...
dh.transform(true) do |r|
  # this index combines the tank dimensions above for best combination (simple Euclidean metric)
  r.nuke_index = r.total_damage * r.total_move_speed * r.total_mana * (r.ability_power)
  r.easy_nuke_index = r.total_damage * r.total_move_speed * r.total_mana * (r.ability_power) * (1.0/r.difficulty)
  r.tenacious_index = r.total_armor * r.total_health * r.total_spell_block * r.total_health_regen * (r.defense_power)
  r.support_index = r.total_mana * r.total_armor * r.total_spell_block * r.total_health * r.total_health_regen * r.total_mana_regen * (r.ability_power * r.defense_power)
  print '.'
end

# use once at the end to mark records processed.
dh.transform_complete
puts "transforms complete"

ds = dh.dataset

binding.pry

puts "done."