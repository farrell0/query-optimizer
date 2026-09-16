#!/usr/bin/env python


#############################################
#############################################


#  Our imports
#
import sys


#  Since this library is not part of the standard Python
#  set, put it in a try/except block.
#

try:
   import psycopg2
   from   psycopg2.extensions import connection
except Exception:
   print()
   print("ERROR: Required library (psycopg2) not found.")
   print(   "This library is required for database connectivity.")
   print()
   print()
   sys.exit(4)


#############################################
#############################################


def f_DBHandle(i_DB_HOST, i_DB_PORT, i_DB_NAME, i_DB_USER,
      i_DB_PASSWORD, i_PROGRAM) -> connection:

   try:
      r_DBHandle = psycopg2.connect(
         host             = str(i_DB_HOST),
         port             = int(i_DB_PORT),
         dbname           = str(i_DB_NAME),
         user             = str(i_DB_USER),
         password         = str(i_DB_PASSWORD),
         connect_timeout  = 10,
         application_name = str(i_PROGRAM)
         )
   except Exception as e:
      print()
      print("ERROR: Database connection attempt failed.")
      print("   " + str(e))
      print()
      print()
      sys.exit(5)

   return r_DBHandle



