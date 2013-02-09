require 'sequel'
require 'ostruct'
require 'logger'

module DataHut
  class DataWarehouse
    private_class_method :new

    def self.connect(name)
      new(name)
    end

    def initialize(name)
      @db = Sequel.sqlite("#{name}.db")
      #@db.logger = ::Logger.new(STDOUT)
      unless @db.table_exists?(:data_warehouse)
        @db.create_table(:data_warehouse) do
          primary_key :dw_id
        end
      end
    end

    def dataset
      Class.new(Sequel::Model(@db[:data_warehouse]))
    end

    def extract(data)
      raise(ArgumentError, "a block is required for extract.", caller) unless block_given?

      data.each do |d|
        r = OpenStruct.new
        yield r, d
        store(r)
      end
    end

    # transform all (could also be limited to not processed)
    def transform
      raise(ArgumentError, "a block is required for transform.", caller) unless block_given?

      # now process all the records with the updated schema...
      dataset.each do |d|
        # first, convert the Sequel::Model to a hash
        h = d.to_hash
        # then get rid of the internal id part
        dw_id = h.delete(:dw_id)
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


    private 

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