require "data_hut/version"
require "data_hut/data_warehouse"


module DataHut
  # Your code goes here...

  def self.connect(name)
    DataWarehouse.connect(name)
  end

end
