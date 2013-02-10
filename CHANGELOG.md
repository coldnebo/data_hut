# Changelog

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
