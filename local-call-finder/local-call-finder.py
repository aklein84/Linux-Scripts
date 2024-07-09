#!/usr/bin/env python

import requests
import xmltodict
import json
from optparse import OptionParser

VERSION = "1.0"

def _getLocalPrefixes(l_area_code, l_prefix):
  r = requests.get(f"https://www.localcallingguide.com/xmllocalprefix.php?npa={l_area_code}&nxx={l_prefix}")
  return_dict = xmltodict.parse(r.text)
  area_dict = dict()
  for x in range(0, len(return_dict['root']['lca-data']['prefix'])):
      area_code = return_dict['root']['lca-data']['prefix'][x]['npa']
      prefix = return_dict['root']['lca-data']['prefix'][x]['nxx']
      if area_code not in area_dict:
        area_dict.setdefault(area_code, [])
      area_dict[area_code].append(prefix)
  return area_dict

def printDialPlan(l_area_code, l_prefix):
  local = _getLocalPrefixes(l_area_code, l_prefix)
  for x in local:
    with open(f"{l_area_code}{l_prefix}_to_{x}Local.csv", "a+") as dialplan:
      dialplan.write('prepend,prefix,"match pattern",callerid')
      for y in local[x]:
        dialplan.seek(0)
        lines = dialplan.read().splitlines()
        if y not in lines:
          dialplan.write(f",,1{x}{y}XXXX,\n")
          dialplan.write(f",,{x}{y}XXXX,\n")

def main():
  parser = OptionParser("Usage: %prog [options]", version = "%prog {version}".format(version = VERSION))
  parser.add_option("-a", "--areacode", action = "store", type = "string", dest  = "areacode", default = False, help = "Area code local to calling station.")
  parser.add_option("-p", "--prefix", action = "store", type = "string", dest = "prefix", default = False, help = "Prefix local to calling station.")
  opt, args = parser.parse_args()

  printDialPlan(opt.areacode, opt.prefix)

if __name__ == '__main__':
  main()
