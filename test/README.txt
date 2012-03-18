# TO RUN THE TESTS...
#
# Create a file named "test/database.yml" with the content below.
# You may need to modify the "libspatialite" value to point to the
# actual path to your libspatialite library.
#
# Make sure the sqlite3, activerecord, and rgeo-activerecord gems
# are installed.
#
# Then run:
#   rake test

adapter: spatialite
encoding: utf8
database: tmp/spatialite_test.db
libspatialite: /usr/local/lib/libspatialite.dylib
