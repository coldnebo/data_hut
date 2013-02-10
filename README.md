# DataHut

A small, portable data warehouse for Ruby for analytics on anything!

DataHut has basic features for small one-off analytics like parsing error logs and such.  Like its bigger cousin (the Data Warehouse) it has support for *extract*, *transform* and *load* processes (ETL).  Unlike its bigger cousin it is simple to setup and use for simple projects.

*Extract* your data from anywhere, *transform* it however you like and *analyze* it for insights!


## Installation

Add this line to your application's Gemfile:

    gem 'data_hut'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install data_hut

## Usage

Setting up a datahut is easy...

    require 'data_hut'
    require 'pry'

    dh = DataHut.connect("scratch")

    data = [{name: "barney", age: 27},
            {name: "phil", age: 31},
            {name: "fred", age: 44}]

    # extract your data by iterating over your data format (from whatever source) and map it to a record model...
    dh.extract(data) do |r, d|
      r.name = d[:name]
      r.age = d[:age]
    end

    # transform your data by adding fields to it
    dh.transform do |r|
      r.eligible = r.age < 30
    end

    # operate on your dataset by using chained queries
    ds = dh.dataset

    binding.pry

The datahut *dataset* is a Sequel::Model backed by the data warehouse you just created. 

And here's the kinds of powerful things you can do:

    [2] pry(main)> ds.where(eligible: false).count
    => 2
    [3] pry(main)> ds.avg(:age)
    => 34.0
    [4] pry(main)> ds.max(:age)
    => 44
    [5] pry(main)> ds.min(:age)
    => 27

But wait, you can name these collections:

    [6] pry(main)> ineligible = ds.where(eligible: false)
    => #<Sequel::SQLite::Dataset: "SELECT * FROM `data_warehouse` WHERE (`eligible` = 'f')">

    [26] pry(main)> ineligible.avg(:age)
    => 37.5
    [24] pry(main)> ineligible.order(Sequel.desc(:age)).all
    => [#< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>,
     #< @values={:dw_id=>2, :name=>"phil", :age=>31, :eligible=>false}>]

The results are Sequel::Model objects, so you can treat them as such:

    [32] pry(main)> record = ineligible.order(Sequel.desc(:age)).first
    => #< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>
    [33] pry(main)> record.name
    => "fred"
    [34] pry(main)> record.age
    => 44


Read more about the [Sequel gem](http://sequel.rubyforge.org/rdoc/files/README_rdoc.html) to determine what operations you can perform on a datahut dataset.

## A More Ambitious Example...

Taking a popular game like League of Legends and hand-rolling some simple analysis of the champions...

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
        names = st.css('td.stats_name').collect{|e| e.text.strip.downcase.gsub(/ /,'_')}
        values = st.css('td.stats_value').collect{|e| e.text.strip}
        modifiers = st.css('td.stats_modifier').collect{|e| e.text.strip}

        dh.store_meta(:stats, names)

        (0..names.count-1).collect do |i| 
          stat = (names[i] + "=").to_sym
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

    # connect again in case extract was skipped because the core data already exists:
    dh = DataHut.connect("lolstats")

    # instead of writing out each stat line manually, we can use some metaprogramming along with some metadata to automate this.
    def total_stat(r,stat)
      total_stat = ("total_" + stat + "=").to_sym
      stat_per_level = r.send((stat + "_per_level").to_sym)
      base = r.send(stat.to_sym)
      total = base + (stat_per_level * 18.0)
      r.send(total_stat, total)
    end
    # we need to fetch metadata that was written during extract (potentially in a previous process run)
    stats = dh.fetch_meta(:stats)

    puts "first transform"
    dh.transform do |r|
      stats.each do |stat|
        total_stat(r,stat)
      end
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


Now that we have some data, lets play...

* who has the most base damage?

        [1] pry(main)> ds.order(Sequel.desc(:damage)).limit(5).collect{|c| {c.name => c.damage}}
        => [{"Taric"=>58.0},
         {"Maokai"=>58.0},
         {"Warwick"=>56.76},
         {"Singed"=>56.65},
         {"Poppy"=>56.3}]


* but wait a minute... what about at level 18?  Fortunately, we've transformed our data to add some extra fields for this...

        [2] pry(main)> ds.order(Sequel.desc(:total_damage)).limit(5).collect{|c| {c.name => c.total_damage}}
        => [{"Skarner"=>129.70000000000002},
         {"Cho'Gath"=>129.70000000000002},
         {"Kassadin"=>122.5},
         {"Taric"=>121.0},
         {"Alistar"=>120.19}]

* how about using some of the indexes we defined above... like the 'nuke_index' (notice that the assumptions on what make a good
nuke are subjective, but that's the fun of it; we can model our assumptions and see how the data changes in response.)

        [3] pry(main)> ds.order(Sequel.desc(:nuke_index)).limit(5).collect{|c| {c.name => [c.total_damage, c.total_move_speed, c.total_mana, c.ability_power]}}
        => [{"Karthus"=>[100.7, 335.0, 1368.0, 10]},
         {"Morgana"=>[114.58, 335.0, 1320.0, 9]},
         {"Ryze"=>[106.0, 335.0, 1240.0, 10]},
         {"Karma"=>[109.4, 335.0, 1320.0, 9]},
         {"Lux"=>[109.4, 340.0, 1150.0, 10]}]

I must have hit close to the mark, because personally I hate each of these champions when I go up against them!  ;)

* and (now I risk becoming addicted to datahut myself), here's some further guesses with an easy_nuke index:

        [4] pry(main)> ds.order(Sequel.desc(:easy_nuke_index)).limit(5).collect{|c| c.name}
        => ["Sona", "Ryze", "Nasus", "Soraka", "Heimerdinger"]

* makes sense, but is still fascinating... what about my crack at a support_index?

        [5] pry(main)> ds.order(Sequel.desc(:support_index)).limit(5).collect{|c| c.name}
        => ["Sion", "Diana", "Nunu", "Nautilus", "Amumu"]



You get the idea now!  *Extract* your data from anywhere, *transform* it however you like and *analyze* it for insights!

Have fun!


## TODOS

* further optimizations
* time-based series and binning helpers (by week/day/hour/5-min/etc).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
