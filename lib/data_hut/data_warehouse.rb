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
    # @return [void]
    # @note Duplicate records (all fields and values must match) are automatically not inserted at the end of an extract iteration. You may
    #   also skip duplicate extracts early in the iteration by using {#not_unique}.
    # @note Fields with nil values in records are skipped because the underlying database defaults these to 
    #   nil already. However you must have at least one non-nil value in order for the field to be automatically created,
    #   otherwise subsequent transform layers may report errors on trying to access the field.
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
    #   See the second transform in {https://github.com/coldnebo/data_hut/blob/master/samples/league_of_legends.rb#L102 samples/league_of_legends.rb:102}.
    # @yield [record] lets you modify the DataHut record
    # @yieldparam record an OpenStruct that fronts the DataHut record.  You may access existing fields on this record or create new 
    #   fields to store synthetic data from a transform pass. 
    #   These fields will automatically be added to the schema behind the DataHut using the ruby data type you assigned to the record.
    #   See {http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html Sequel Schema Modification Methods} for 
    #   more information about supported ruby data types you can use.
    # @raise [ArgumentError] if you don't provide a block
    # @return [void]
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
        # get the update hash from the openstruct
        h = ostruct_to_hash(r)
        # now add any new transformation fields to the schema...
        adapt_schema(h)
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
    #
    # @return [void]
    def transform_complete
      @db[:data_warehouse].update(:dw_processed => true)
    end

    # attach a Logger to the underlying Sequel database so that you can debug or monitor database actions.
    # See {http://sequel.rubyforge.org/rdoc/classes/Sequel/Database.html#method-i-logger-3D Sequel::Database#logger=}.
    #
    # @example 
    #   dh.logger = Logger.new(STDOUT)
    #
    # @param logger [Logger] a logger for the underlying Sequel actions.
    # @raise [ArgumentError] if passed a logger that is not a kind of {http://www.ruby-doc.org/stdlib-1.9.3//libdoc/logger/rdoc/Logger.html Logger}.
    # @return [void]
    def logger=(logger)
      raise(ArgumentError, "logger must be a type of Logger.") unless logger.kind_of?(Logger)
      @db.logger = logger
    end

    # stores any Ruby object as metadata in the datahut.
    #
    # @param key [Symbol] to reference the metadata by
    # @param value [Object] ruby object to store in metadata
    # @return [void]
    # @note Because the datastore can support any Ruby object (including custom ones) it is up to 
    #   the caller to make sure that custom classes are in context before storage and fetch.  i.e. if you 
    #   store a custom object and then fetch it in a context that doesn't have that class loaded, you'll get an error.  
    #   For this reason it is safest to use standard Ruby types (e.g. Array, Hash, etc.) that will always be present.
    def store_meta(key, value)
      key = key.to_s if key.instance_of?(Symbol)
      begin 
        value = Sequel::SQL::Blob.new(Marshal.dump(value))
        if (@db[:data_warehouse_meta].where(key: key).count > 0)
          @db[:data_warehouse_meta].where(key: key).update(value: value)
        else
          @db[:data_warehouse_meta].insert(key: key, value: value)
        end
      rescue Exception => e
        raise(ArgumentError, "DataHut: unable to store metadata value #{value.inspect}: #{e.message}", caller)
      end
    end

    # retrieves any Ruby object stored as metadata.
    #
    # @param key [Symbol] to lookup the metadata by
    # @return [Object] ruby object that was fetched from metadata
    # @note Because the datastore can support any Ruby object (including custom ones) it is up to 
    #   the caller to make sure that custom classes are in context before storage and fetch.  i.e. if you 
    #   store a custom object and then fetch it in a context that doesn't have that class loaded, you'll get an error.  
    #   For this reason it is safest to use standard Ruby types (e.g. Array, Hash, etc.) that will always be present.
    def fetch_meta(key)
      key = key.to_s if key.instance_of?(Symbol)
      begin
        r = @db[:data_warehouse_meta].where(key: key).first
        value = r[:value] unless r.nil?
        value = Marshal.load(value) unless value.nil?
      rescue Exception => e
        raise(RuntimeError, "DataHut: unable to fetch metadata key #{key}: #{e.message}", caller)
      end
      value
    end

    # used to determine if the specified fields and values are unique in the datahut.
    # 
    # @example
    #   dh.extract(data) do |r, d|
    #     next if dh.not_unique(name: d[:name])
    #     r.name = d[:name]
    #     r.age = d[:age]
    #     ...
    #   end
    #
    # @note exactly duplicate records are automatically skipped at the end of an extract iteration (see {#extract}). This 
    #   method is useful if an extract iteration takes a long time and you want to skip duplicates early in the iteration.
    # @param hash [Hash] of the key, value pairs specifying a partial record by which to consider records unique.
    # @return [Boolean] true if the {field: value} already exists, false otherwise (including if the column doesn't yet exist.)
    def not_unique(hash)
      @db[:data_warehouse].where(hash).count > 0 rescue false
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

      unless @db.table_exists?(:data_warehouse_meta)
        @db.create_table(:data_warehouse_meta) do
          primary_key :dw_id
          String :key
          index :key
          blob :value
        end
      end
    end

    def store(r)
      h = ostruct_to_hash(r)
      adapt_schema(h)
      # don't insert dups
      unless not_unique(h)
        @db[:data_warehouse].insert(h)
      end
    end

    def ostruct_to_hash(r)
      h = r.marshal_dump
      h.reject{|k,v| v.nil?}  # you can't define a column type "NilClass", so strip these before adapting the schema
    end

    def adapt_schema(h)
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