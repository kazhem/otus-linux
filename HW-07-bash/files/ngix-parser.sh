#!/usr/bin/env bash
###
# analyze nginx's access.log and send results to email
###

#set -exo pipefail

# Set default values for variables
RECIPIENT='root'
LOGFILE='./access.log'
LOCKFILE='/tmp/script.lock'
STATE_DIR='./nginx_log_analyzer'
TOP=10

# Set permanent ariables values
STATE_FILE_NAME="state.env"
MSGBODY_FILE=$(mktemp)

# Print usage information
usage() {
  echo "Usage: $0 options"
  printf "\t-r|--recipient <destination email> - email address to send statistics to. Default: '%s'\n" "$RECIPIENT"
  printf "\t-l|--logfile <path/to/access.log> - path to nginx access.log to analyse. Default: '%s'\n" "$LOGFILE"
  printf "\t-L|--lockfile <path/to/lockfile.lock> - path to lockfile. Default: '%s'\n" "$LOCKFILE"
  printf "\t-S|--state-dir <path/to/state/directory> - path to directory to save state. Default: '%s'\n" "$STATE_DIR"
  printf "\t-T|--top <num> - report top <num> results. Default: %i\n" "$TOP"
  printf "\t-h|--help - Print this help and exit\n"
  exit ${1:-0}
}

# Run on script termination
terminate() {
  echo "Terminated! Removing lockfile $LOCKFILE"
  rm -f "$LOCKFILE"
  rm -f "$MSGBODY_FILE"
  exit $?
}

# Send statistics to email
send_email() {
  cat $1 | wc -l
  cat $1 > ./result.txt
  cat $1 | mailx -v -s 'access.log stats' $RECIPIENT
}

# Parse arguments
while true; do
  case "$1" in
  -r | --recipient)
    RECIPIENT="${2}"
    shift 2
    ;;
  -l | --logfile)
    LOGFILE="${2}"
    shift 2
    ;;
  -L | --lockfile)
    LOCKFILE="${2}"
    shift 2
    ;;
  -S | --state-dir)
    STATE_DIR="${2}"
    shift 2
    ;;
  -T | --top)
    TOP="${2}"
    shift 2
    ;;
  -h | --help)
    usage
    shift 1
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done

# debug options
cat <<EOF
RECIPIENT=$RECIPIENT
LOGFILE=$LOGFILE
LOCKFILE=$LOCKFILE
STATE_DIR=$STATE_DIR
TOP=$TOP
MSGBODY_FILE=$MSGBODY_FILE
EOF

# Try to acquire lockfile
if (
  set -o noclobber
  echo "$$" >"$LOCKFILE"
) 2>/dev/null; then
  trap 'terminate' INT TERM EXIT
else
  echo "Failed to acquire lockfile: $LOCKFILE."
  echo "Held by $(cat ${LOCKFILE})"
  exit 1
fi

###############################################

##
# Define filters
##
http_only() {
  grep --color=never -P ' HTTP/[\d\.]+"'
}

##
# Define analyzers
##
top_n() {
  awk '{ print $1; }' | sort -n | uniq -c | sort -rn | head -n $TOP
}

##
# Define helpers
##
# Get last logfile position or create new state file
get_last_position() {
  mkdir -p "${STATE_DIR}" || {
    echo "ERROR: state directory '$STATE_DIR' must exists"
    usage 1
  }
  test -w "${STATE_DIR}" || {
    echo "ERROR: Directory '$STATE_DIR' must be writable"
    usage 1
  }
  STATE_FILE="${STATE_DIR}/${STATE_FILE_NAME}"
  test -f "$STATE_FILE" || { echo "FROM_LINE=1" >$STATE_FILE; }
  source $STATE_FILE
}

##
# Read log from $FROM_LINE to end of file
##
# Read current state ($FROM_LINE)
get_last_position
# Set TO_LINE as file length
TO_LINE=$(wc -l $LOGFILE | cut -d" " -f1)
# Check new lines were added
test $FROM_LINE -eq $TO_LINE && {
  echo "No new lines. Exiting"
  exit 0
}
# Save last position to $STATE_FILE
echo "FROM_LINE=$TO_LINE" >$STATE_FILE

# Period
FROM_DT=$(sed -n "$(($FROM_LINE + 1)),$(($FROM_LINE + 1))p" $LOGFILE | cut -d"[" -f2 | cut -d"]" -f1)
TO_DT=$(sed -n "$(($TO_LINE)),$(($TO_LINE))p" $LOGFILE | cut -d"[" -f2 | cut -d"]" -f1)
echo "Period from $FROM_DT to $TO_DT" >$MSGBODY_FILE
# Top IPs
echo "--------" >>$MSGBODY_FILE
echo "Top $TOP IPs" >>$MSGBODY_FILE
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | awk '{ print $1; }' | top_n >>$MSGBODY_FILE
# Top requested URIs
echo "--------" >>$MSGBODY_FILE
echo "Top $TOP requested URIs" >>$MSGBODY_FILE
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '{ print $7; }' | top_n >>$MSGBODY_FILE
# Return codes
echo "--------" >>$MSGBODY_FILE
echo "Return codes count" >>$MSGBODY_FILE
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '{ print $9; }' | sort -n | uniq -c | sort -rn >>$MSGBODY_FILE
# Errors
echo "--------" >>$MSGBODY_FILE
printf "Errors (4xx and 5xx):\n\n" >>$MSGBODY_FILE
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '$9 ~ /[45][0-9]{2}/ { print $0; }' >>$MSGBODY_FILE
echo "" >>$MSGBODY_FILE

send_email $MSGBODY_FILE
