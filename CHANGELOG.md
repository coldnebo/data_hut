
0.0.4
-----

* added the capability to mark records in the datahut as processed so that transform passes can ignore previously processed data and only process new data... good for cycles where you pull regular updates and then process them.

* added capability to force the transform to write in spite of processed; good for situations where you are playing with the structure of the transform and want to regenerate the data.


0.0.3
-----

* fixed an update issue found in transforms where data was written successfully, but Sequel::Model couldn't read it immediately after.


0.0.2
-----

* fixed problem with multiple instances of the datahut returning only a single dataset instance.

* added more interesting example to motivate edge cases.


0.0.1
-----

* initial checkin. basic functionality
