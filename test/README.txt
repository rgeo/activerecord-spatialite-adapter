# TO RUN THE TESTS...
#
# Create a file named "test/database.yml" with the content below.
# If your libspatialite.{so,dylib} is not in a "typical" location,
# you may need to uncomment the libspatialite value and provide the
# full path to the library.
#
# Make sure the sqlite3, activerecord, and rgeo-activerecord gems
# are installed.
#
# Then run:
#   rake test

adapter: spatialite
encoding: utf8
database: tmp/spatialite_test.db
# libspatialite: /usr/local/lib/libspatialite.so
