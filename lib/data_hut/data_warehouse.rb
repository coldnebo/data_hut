require 'sequel'
require 'ostruct'
require 'logger'

module DataHut

  # The DataHut::DataWarehouse comprehensively manages all the heavy lifting of creating a data system for your analytics.
  # So during *extract* and *transform* phases you don't have to worry about the schema or the data types you'll be using... 
  # just start scraping and playing with the data extraction, DataHut will take care of introspecting your final data records
  # and creating or altering the DataHut schema for you, auto-magically.
  #
  # @example 
  #   require 'data_hut'
  #   require 'pry'   # not necessary, but very useful
  #
  #   dh = DataHut.connect("scratch")
  #   data = [{name: "barney", age: 27, login: DateTime.parse('2008-05-03') },
  #           {name: "phil", age: 31},
  #           {name: "fred", age: 44, login: DateTime.parse('2013-02-07')}]
  #
  #   # extract your data by iterating over your data format (from whatever source) and map it to a record model...
  #   dh.extract(data) do |r, d|
  #     r.name = d[:name]
  #     r.age = d[:age]
  #     # you can do anything you need to within the extract block to ensure data quality if you want:
  #     d[:login] = DateTime.new unless d.has_key?(:login)
  #     r.last_active = d[:login]
  #     print 'v'
  #   end
  #
  #   # transform your data by adding fields to it
  #   dh.transform do |r|
  #     r.eligible = r.age < 30
  #     print '*'
  #   end
  #
  #   # mark all the records as processed to avoid re-transforming them.
  #   dh.transform_complete
  #   ds = dh.dataset
  #   binding.pry   # play with ds.
  #   [1] pry(main)> ds.avg(:age)
  #   => 34.0
  #   [2] pry(main)> ineligible = ds.where(eligible: false)
  #   [3] pry(main)> ineligible.avg(:age)
  #   => 37.5 
  class DataWarehouse
    private_class_method :new

    # creates or opens an existing connection to a DataHut data store.
    #
    # @param name [String] name of the DataHut.  This will also be the name of the sqlite3 file written 
    #   to the current working directory (e.g. './<name>.db')
    # @return [DataHut::DataWarehouse] instance
    def self.connect(name)
      new(name)
    end

    # access the DataHut dataset. See {http://sequel.rubyforge.org/rdoc/classes/Sequel/Dataset.html Sequel::Dataset} 
    # for available operations on the dataset. 
    # 
    # @return [Sequel::Model] instance bound to the data warehouse. Use this handle to query and analyze the datahut.
    def dataset
      Class.new(Sequel::Model(@db[:data_warehouse]))
    end

    # used to extract data from whatever source you wish. As long as the data forms an enumerable collection, 
    # you can pass it to extract along with a block that specifies how you which the DataHut *record* to be 
    # mapped from the source *element* of the collection.
    # 
    # @example Extracting fields from a hash and assigning it to a field on a record
    #  data = [{name: "barney", age: 27, login: DateTime.parse('2008-05-03') }]
    #  dh.extract(data) do |r, d|
    #    r.name = d[:name]
    #    r.age  = d[:age]
    #  end
    # 
    # @param data [Enumerable]
    # @yield [record, element] lets you control the mapping of data elements to record fields
    # @yieldparam record an OpenStruct that allows you to create fields dynamically on the record as needed. 
    #   These fields will automatically be added to the schema behind the DataHut using the ruby data type you assigned to the record.
    #   See {http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html Sequel Schema Modification Methods} for 
    #   more information about supported ruby data types you can use.
    # @yieldparam element an element from your data.
    # @raise [ArgumentError] if you don't provide a block
    def extract(data)
      raise(ArgumentError, "a block is required for extract.", caller) unless block_given?

      data.each do |d|
        r = OpenStruct.new
        yield r, d
        store(r)
      end
    end

    # used to transform data already extracted into a DataHut.  You can also use *transform* to create new synthetic data fields 
    # from existing fields.  You may create as many transform blocks (i.e. 'passes') as you like.
    #
    # @example Defining 'eligibility' based on arbitrary age criteria.
    #   dh.transform do |r|
    #     r.eligible = r.age < 30      # using extracted to create a synthetic boolean field
    #   end
    # 
    # @param forced if set to 'true', this transform will iterate over records already marked processed.  This can be useful for 
    #   layers of transforms that deal with analytics where the analytical model may need to rapidly change as you explore the data.
    #   See the second transform in {file/README.md#A_More_Ambitious_Example___}.
    # @yield [record] lets you modify the DataHut record
    # @yieldparam record an OpenStruct that fronts the DataHut record.  You may access existing fields on this record or create new 
    #   fields to store synthetic data from a transform pass. 
    #   These fields will automatically be added to the schema behind the DataHut using the ruby data type you assigned to the record.
    #   See {http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html Sequel Schema Modification Methods} for 
    #   more information about supported ruby data types you can use.
    # @raise [ArgumentError] if you don't provide a block
    def transform(forced=false)
      raise(ArgumentError, "a block is required for transform.", caller) unless block_given?

      # now process all the records with the updated schema...
      @db[:data_warehouse].each do |h|
        # check for processed if not forced
        unless forced
          next if h[:dw_processed] == true
        end
        # then get rid of the internal id and processed flags
        dw_id = h.delete(:dw_id)
        h.delete(:dw_processed)
        # copy record fields to an openstruct
        r = OpenStruct.new(h)
        # and let the transformer modify it...
        yield r
        # now add any new transformation fields to the schema...
        adapt_schema(r)
        # get the update hash from the openstruct
        h = r.marshal_dump
        # and use it to update the record
        @db[:data_warehouse].where(dw_id: dw_id).update(h)
      end
    end

    # marks all the records in the DataHut as 'processed'.  Useful as the last command in a sequence of extract and transform passes.
    # 
    # @example a simple log analysis system (pseudocode)
    #   rake update
    #      extract apache logs  (only adds new logs since last update)
    #      transform logs into types of response (error, ok, met_SLA (service level agreement, etc.))  (only transforms unprocessed (new) logs)
    #      transform_complete (marks the update complete)
    #      dh.dataset is used to visualize graphs with d3.js
    #   end
    def transform_complete
      @db[:data_warehouse].update(:dw_processed => true)
    end

    def logger=(logger)
      raise(ArgumentError, "logger must be a type of Logger.") unless logger.kind_of?(Logger)
      @db.logger = logger
    end

    private 

    def initialize(name)
      @db_file = "#{name}.db"
      @db = Sequel.sqlite(@db_file)
      
      unless @db.table_exists?(:data_warehouse)
        @db.create_table(:data_warehouse) do
          primary_key :dw_id
          column :dw_processed, TrueClass, :null => false, :default => false
        end
      end
    end

    def store(r)
      adapt_schema(r)
      h = r.marshal_dump
      # don't insert dups
      unless @db[:data_warehouse].where(h).count > 0
        @db[:data_warehouse].insert(h)
      end
    end

    def adapt_schema(r)
      h = r.marshal_dump
      h.keys.each do |key|
        type = h[key].class
        unless Sequel::Schema::CreateTableGenerator::GENERIC_TYPES.include?(type)
          raise(ArgumentError, "DataHut: Ruby type '#{type}' not supported by Sequel. Must be one of the supported types: #{Sequel::Schema::CreateTableGenerator::GENERIC_TYPES.inspect}", caller)
        end
        unless @db[:data_warehouse].columns.include?(key)
          @db.alter_table(:data_warehouse) do 
            add_column key, type
            add_index key
          end
        end
      end
    end

  end
end