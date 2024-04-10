#! /bin/bash
MIGRATION_FILE_INPUT=$1
DOWNLOAD_DIR_INPUT=$2

DEBUG="false"
INPUT_FILE_TYPE='invalid'
EXTRACT_ARCHIVES='true'
DELETE_ARCHIVES='true'
LOG_FILE=$DOWNLOAD_DIR_INPUT/account-migration.log

# Helper functions
function blank() {
  local n=${1:-1}
  for ((i = 0; i < n; i++)); do
    echo ""
  done
}

function log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

function log_only() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >>"$LOG_FILE"
}

function run() {
  log "$@"
  "$@" | tee -a "$LOG_FILE"
}

function run_quiet() {
  log_only "$@"
  "$@" | tee -a "$LOG_FILE"
}

function abspath() {
  # generate absolute path from relative path
  # $1     : relative filename
  # return : absolute path
  if [ -d "$1" ]; then
    # dir
    (
      cd "$1" || exit 1
      pwd
    )
  elif [ -f "$1" ]; then
    # file
    if [[ $1 = /* ]]; then
      echo "$1"
    elif [[ $1 == */* ]]; then
      echo "$(
        cd "${1%/*}" || exit 1
        pwd
      )/${1##*/}"
    else
      echo "$(pwd)/$1"
    fi
  fi
}

log '### MIGRATION FETCH START ###'
if [[ -z "$MIGRATION_FILE_INPUT" ]]; then
  log "No migration file defined"
  exit 1
fi

# Verify input file extension is correct
if [[ $MIGRATION_FILE_INPUT == *.json.gz ]]; then
  INPUT_FILE_TYPE='gzip'
fi

if [[ $MIGRATION_FILE_INPUT == *.json ]]; then
  INPUT_FILE_TYPE='json'
fi

if [[ $INPUT_FILE_TYPE == 'invalid' ]]; then
  log "Invalid file extension provided"
  exit 1
fi

if [[ -z "$DOWNLOAD_DIR_INPUT" ]]; then
  log "Specify a download directory to continue"
  exit 1
fi

# Determine absolute paths for inputs
MIGRATION_FILE_PATH=$(abspath "$MIGRATION_FILE_INPUT")
DOWNLOAD_DIR=$(abspath "$DOWNLOAD_DIR_INPUT")

# Set migration filename and ID variables for use later
MIGRATION_FILENAME=$(basename "$MIGRATION_FILE_PATH")

if [[ $MIGRATION_FILENAME =~ (mig_[^.]+) ]]; then
  MIGRATION_ID="${BASH_REMATCH[1]}"
else
  log "Migration file name mangled and unable to determine migration ID"
  exit 1
fi

# Check directory actually exists
if [[ ! -d $DOWNLOAD_DIR ]]; then
  log "Specified directory $DOWNLOAD_DIR doesn't exist. 
        Create directory or specify a different location"
  exit 1
fi

WORKING_DIR="$DOWNLOAD_DIR/$MIGRATION_ID"
INDEX_DIR="$WORKING_DIR/indices"
log "Using working directory: $WORKING_DIR"
blank
if [[ -d $WORKING_DIR ]]; then
  log "$WORKING_DIR exists!!!"
  log "If you continue all contents of the directory will be deleted with!"
  log "rm -rf ${WORKING_DIR:?}/*"
  log_only "Are you sure you want to contine?[y/N]"
  read -rp "Are you sure you want to contine?[y/N]" user_confirm_deletion

  case $user_confirm_deletion in
  [Yy]*)
    log "Clearing working directory"
    run rm -rf "${WORKING_DIR:?}/"*
    run mkdir "$INDEX_DIR"
    ;;
  *)
    log "Yes not explicitly set aborting before destructive operation."
    exit 1
    ;;
  esac
else
  run mkdir "$WORKING_DIR"
  run mkdir "$INDEX_DIR"
fi

if [[ $INPUT_FILE_TYPE == 'gzip' ]]; then
  INDEX_JSON_FILENAME="${MIGRATION_FILENAME%.gz}"
  run gzip -dk "$MIGRATION_FILE_PATH"
  run mv "${MIGRATION_FILE_PATH%.gz}" "$WORKING_DIR/$INDEX_JSON_FILENAME"
else
  run cp "$MIGRATION_FILE_PATH" "$WORKING_DIR/$MIGRATION_FILENAME"
  INDEX_JSON_FILENAME="$MIGRATION_FILENAME"
fi

INDEX_JSON_FILE_PATH="$WORKING_DIR/$INDEX_JSON_FILENAME"

if [[ $DEBUG == 'true' ]]; then
  log_only "###################"
  log_only "### Diagnostics ###"
  log_only "###################"
  log_only "Migration file input:"
  log_only "$MIGRATION_FILE_INPUT"
  log_only "Migration filename:"
  log_only "$MIGRATION_FILENAME"
  log_only "Migration file path:"
  log_only "$MIGRATION_FILE_PATH"
  log_only "Migration ID:"
  log_only "$MIGRATION_ID"
  log_only "Download directory:"
  log_only "$DOWNLOAD_DIR_INPUT"
  log_only "Download directory path:"
  log_only "$DOWNLOAD_DIR"
  log_only "Working directory path:"
  log_only "$WORKING_DIR"
fi

blank
log "### BEGIN WORK ###"
blank

migration_type=$(jq -r ".migration_type" "$INDEX_JSON_FILE_PATH")
accounts_count=$(jq -r ".accounts_count" "$INDEX_JSON_FILE_PATH")
templates_count=$(jq -r ".templates_count" "$INDEX_JSON_FILE_PATH")
submissions_count=$(jq -r ".submissions_count" "$INDEX_JSON_FILE_PATH")
combined_submissions_count=$(jq -r ".combined_submissions_count" "$INDEX_JSON_FILE_PATH")

log "# Selected index is a $migration_type migration with:"
if ((accounts_count > 0)); then
  log "  - $accounts_count accounts"
fi

if ((accounts_count > 0)); then
  log "  - $accounts_count accounts"
fi

if ((templates_count > 0)); then
  log "  - $templates_count templates"
fi

if ((submissions_count > 0)); then
  log "  - $submissions_count submissions"
fi

if ((combined_submissions_count > 0)); then
  log "  - $combined_submissions_count combined submissions"
fi

while true; do
  log "----------------------------------"
  log "This download could take some time:"
  log "  - Delete archives after extraction      : Y/y"
  log "  - Keep archives after extraction        : K/k"
  log "  - Downloads archives only               : D/d"
  log "  - Exits without downloading anything    : N/n"
  log "----------------------------------"
  log_only "Do you want to contine?[Y/k/d/n]"
  read -rp "Do you want to contine?[Y/k/d/n] " user_select_option

  case "${user_select_option:=y}" in
  [Yy]*)
    log "Beginning download and extraction of archives with clean up to $WORKING_DIR"
    break
    ;;
  [Kk]*)
    log "Beginning download and extraction of archives to $WORKING_DIR"
    DELETE_ARCHIVES='false'
    break
    ;;
  [Dd]*)
    log "Beginning download of archives to $WORKING_DIR"
    EXTRACT_ARCHIVES='true'
    break
    ;;
  [Nn])
    log "User aborted download"
    exit 1
    ;;
  *)
    blank
    log "!!! Please select a valid option !!!"
    blank 2
    ;;
  esac
done

jq_opts='.batches[] | .parts[]'
run_quiet jq -r "$jq_opts" "$INDEX_JSON_FILE_PATH" | while read -r url; do
  # if [[ $MIGRATION_FILENAME =~ (mig_[^.]+) ]]; then
  if [[ $url =~ (mbp_[^.]+) ]]; then
    part_id="${BASH_REMATCH[1]}"
    filename="$WORKING_DIR/$part_id.tar.gz"
    log "### processing $filename"
    log "### Fetching..."
    run wget --progress=dot:binary -O "$filename" "$url"
    if [[ $EXTRACT_ARCHIVES == 'true' ]]; then
      log "### Extracting..."
      run tar xf "$filename" -C "$WORKING_DIR"
      if [[ $DELETE_ARCHIVES == 'true' ]]; then
        log "### Cleaning..."
        run rm "$filename"
      fi
      run mv "$WORKING_DIR/index.json" "$INDEX_DIR/${part_id}_index.json"
    fi
    log "### Done"
    blank 2
  else
    log "!!! URL does not contain the expected pattern."
    log "URL: $url"
  fi
done

log '### MIGRATION FETCH DONE ###'
