#!/usr/bin/env python


#############################################
#############################################


import psycopg2
from   psycopg2.extensions import connection


#############################################
#############################################


print()

l_DBHandle = psycopg2.connect(
   host             = "D1-Yuga-C6N1",
   port             = 5433,
   dbname           = "yugabyte",
   user             = "yugabyte",
   password         = "",
   connect_timeout  = 10,
   application_name = "p_testDBConn"
   )

l_cursor = l_DBHandle.cursor()

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
   #
print()
print()





