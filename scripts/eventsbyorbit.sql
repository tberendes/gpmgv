select orbit, min(overpassdtime), max(overpassdtime)
from ct_temp where proximity < 150
group by orbit order by orbit;

-- ls -lT | sed 's/  */ /g' | cut -f 6-10 -d ' '

ls -lT | sed 's/  */ /g' | cut -f 6-10 -d ' ' | awk 'NR==2; {print $2"-"$1"-"$4, $3"|"$5}'

ls -lT | sed 's/  */ /g' | cut -f 6-10 -d ' ' | awk '{print $5"."$4"-" $2"-"$1"."$3}'