#!/bin/bash

LOG_URL=$(grep 'URL' secretss | sed 's/^URL\s*=\s*//')
TIMESTAMP=$(date +"%Y_%m_%d_%H:%M:%S")
RESULT_FILE="result_${TIMESTAMP}"
LOG_FILE="test.log"
cookie=$(grep 'Cookie' secretss | sed 's/^Cookie\s*=\s*//')
curl "$LOG_URL" -H "Cookie: $cookie " -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64)" -o $LOG_FILE
check_password_strength() {
  local password="$1"
  if [[ ${#password} -ge 12 ]] &&
     echo "$password" | grep -q '[A-Za-z]' &&
     echo "$password" | grep -q '[0-9]' &&
     echo "$password" | grep -q '[[:punct:]]'; then
    echo "strong"
  else
    echo "weak"
  fi
}

{
  echo "softdbpasswords {"
  grep "'softdbpass' => '" "$LOG_FILE" | while read -r line; do
    password=$(echo "$line" | grep -o "'softdbpass' => '[^']*'" | cut -d"'" -f4)
    if [ -n "$password" ]; then
      strength=$(check_password_strength "$password")
      echo "    $password - $strength"
    fi
  done
  echo "}"
  echo
  echo "adminpasswords {"
  grep "'admin_pass' => '" "$LOG_FILE" | while read -r line; do
    password=$(echo "$line" | grep -o "'admin_pass' => '[^']*'" | cut -d"'" -f4)
    if [ -n "$password" ]; then
      strength=$(check_password_strength "$password")
      echo "    $password - $strength"
    fi
  done
  echo "}"

  echo
  echo "Finished and Completed{"
  echo "    Finished - $(grep -o 'Finished' $LOG_FILE | wc -l)"
  echo "    Completed - $(grep -o 'Completed' $LOG_FILE | wc -l)"
  echo "}"
} > "$RESULT_FILE"