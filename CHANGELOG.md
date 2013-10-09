# Changelog

## 0.1.0

* support for jruby

## 0.0.9

* added to_json support for dataset results.

## 0.0.8 

* handle unsanitized nil values properly - If your input data has occasional nil values during extract or transform, you may have seen:
        `DataHut: Ruby type 'NilClass' not supported by Sequel...`
  DataHut now handles nil values instead of raising this exception so that it is easier to work with unsanitized datasets.

* added `DataHut::DataWarehouse#non_unique` which allows you to specify any test of uniqueness for early skipping during transform or extract phases.  DataHut has duplicate detection built-in, i.e. it doesn't allow identical records to be inserted.  However in the past, you had to wait for all the fields to be added or transformed before this detection was done.  `non-unique` allows you to define more specific uniqueness paramters for early skipping without going through all that.  i.e. you have a feed where you know a dup is some kind of GUID... simply test if the GUID is unique *before* going any further...

        dh.extract(data) do |r, d|
          next if dh.not_unique(guid: d[:guid])
          r.guid = d[:guid]
          r.name = d[:name]
          r.age = d[:age]
          ...
        end

## 0.0.7

* added capability to store and fetch arbitrary metadata from the DataHut. 

  This is useful in the case motivated by the samples/league_of_legends.rb:
    stat name is known at initial extract time, however
    subsequent transform runs may or may not have any transient variables for stat names... hence the metadata needs to be stored 
    somewhere for future transform processing.
    note: stat name is not of the same cardinality as the data records themselves, so it is truly metadata that governs how the records
    are understood.

## 0.0.6 

* externalized the Sequel database logger so that it can be set by DataHut clients.  See DataHut::DataWarehouse#logger=

* added type checking on extract and transform to ensure safe operation with underlying Sequel sqlite3 database.

## 0.0.5

* added rdoc

* added tests; 100% code coverage.

## 0.0.4

* added the capability to mark records in the datahut as processed so that transform passes can ignore previously processed data and only process new data... good for cycles where you pull regular updates and then process them.

* added capability to force the transform to write in spite of processed; good for situations where you are playing with the structure of the transform and want to regenerate the data.


## 0.0.3

* fixed an update issue found in transforms where data was written successfully, but Sequel::Model couldn't read it immediately after.


## 0.0.2

* fixed problem with multiple instances of the datahut returning only a single dataset instance.

* added more interesting example to motivate edge cases.


## 0.0.1

* initial checkin. basic functionality
