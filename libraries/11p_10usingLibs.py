#!/usr/bin/env python


THIS_PROGRAM = "11_10usingLibs.py"


####################################################################
####################################################################


#  Import libraries that are commonly part of the 
#  Python run time.

import sys


#  Our custom libraries
#
import l_getConfig 
import l_getDBHandle


#  Import libraries that might not be so common
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


####################################################################
####################################################################


def f_processLoop(i_DBHandle):

   l_cursor = i_DBHandle.cursor()

   l_sql = (
      "SELECT host,port,num_connections,node_type,cloud,region,zone "
      "FROM yb_servers() "
      "ORDER BY host "
      )
   
   l_cursor.execute(l_sql)
   
   print("host                port    num_connections   node_type     cloud        region       zone")
   print("==================  ======  ================  ============  ===========  ===========  ============")
   
   while True:
      l_row = l_cursor.fetchone()
      if (l_row is None):
         break
   
      l_host            = l_row[0]
      l_port            = l_row[1]
      l_num_connections = l_row[2]
      l_node_type       = l_row[3]
      l_cloud           = l_row[4]
      l_region          = l_row[5]
      l_zone            = l_row[6]
   
      print(f"{l_host:<18}  {l_port:<6d}  {l_num_connections:<16d}  {l_node_type:<12}  {l_cloud:<12} {l_region:<12} {l_zone:<12}")
   
   
   l_cursor.close()


####################################################################
####################################################################


#  Our program main
#

if __name__ == "__main__":
   

   ##############################
   #  Get our program config data
   ##############################

   l_config   = l_getConfig.f_configFile("../", "properties.ini")
      #
   DB_HOST              = l_config.get   ("database",
      "DATABASE_HOST"        , fallback="").strip()
   DB_PORT              = l_config.getint("database",
      "DATABASE_PORT"        , fallback=5433);
   DB_NAME              = l_config.get   ("database",
      "DATABASE_NAME"        , fallback="").strip();
   DB_USER              = l_config.get   ("database",
      "DATABASE_USER"        , fallback="").strip();
   DB_PASSWORD          = l_config.get   ("database",
      "DATABASE_PASSWORD"    , fallback="");


   ##############################
   #  Get our database connection handle
   ##############################

   l_DBHandle = l_getDBHandle.f_DBHandle(DB_HOST, DB_PORT, DB_NAME,
      DB_USER, DB_PASSWORD, THIS_PROGRAM)
         #
   print()
   print()
   print("INFO: Got our database connection handle.")


   ##############################
   #  Run our main processing loop
   ##############################

   print("INFO: Processing...")
   print()
         #
   f_processLoop(l_DBHandle)

   print()
   print()








