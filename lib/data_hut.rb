require "data_hut/version"
require "data_hut/data_warehouse"



module DataHut

  # convenience method to create or open an existing connection to a DataHut data store.
  #
  # @param name [String] name of the DataHut.  This will also be the name of the sqlite3 
  #   file written to the current working directory (e.g. './<name>.db')
  # @return [DataHut::DataWarehouse] instance
  # @see DataHut::DataWarehouse#connect
  def self.connect(name)
    DataWarehouse.connect(name)
  end

end
