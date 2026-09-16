#!/usr/bin/env python


#############################################
#############################################


#  Our imports
#

import os
   #
import configparser


#############################################
#############################################


def f_configFile(i_relPath: str, i_file: str) -> configparser.ConfigParser:

   if not (os.path.exists(os.path.join(i_relPath, i_file))):
      raise FileNotFoundError(f"ERROR: Application program INI file not found... {i_relPath}{i_file}")

   r_configFile = configparser.ConfigParser()
   r_configFile.read(os.path.join(i_relPath, i_file))

   return r_configFile




