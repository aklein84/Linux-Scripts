## local-call-finder.py

I created this python script to take the area code and prefix of a location and dump a dial pattern (CSV format) of area codes and prefixes that are local to that number. I am then able to import this CSV into FreePBX to create the necessary outbound routes. 

### Example ###
`./local-call-finder.py --areacode XXX --prefix XXX`


