require 'sequel'
require 'ostruct'

module DataHut
  class DataWarehouse
    private_class_method :new

    def self.connect(name)
      new(name)
    end

    def initialize(name)
      @db = Sequel.sqlite("#{name}.db")
      unless @db.table_exists?(:data_warehouse)
        @db.create_table(:data_warehouse) do
          primary_key :dw_id
        end
      end
    end

    def dataset
      Sequel::Model(:data_warehouse)
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

      dataset.each do |d|
        h = d.to_hash
        dw_id = h.delete(:dw_id)

        src_fields = h.keys
        # copy src fields to an openstruct
        r = OpenStruct.new(h)
        # let the transformer modify it...
        yield r
        #dst_fields = r.marshal_dump.keys
        #diff_fields = dst_fields - src_fields
        # add any new transformation fields to the schema...
        adapt_schema(r)
        # dump as hash
        h = r.marshal_dump
        # remove the source fields
        h.delete(src_fields)
        # update only the destination fields
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