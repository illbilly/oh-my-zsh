# To use: add a .jira-url, jira_user & jira_pass file in the base of your project
#         You can also set JIRA_URL, JIRA_USER & JIRA_PASS in your .zshrc or put .jira-url in your home directory
#         .jira-url in the current directory takes precedence
#
# If you use Rapid Board, set:
# JIRA_RAPID_BOARD="true"
# in you .zshrc
#
# Setup: cd to/my/project
#        echo "https://name.jira.com" >> .jira-url
#        echo "john" >> .jira-user
#        echo "pass" >> .jira-pass
#
# Dependencies:
#   Node.js: http://nodejs.org/ | brew npm
#   underscore cli: https://github.com/ddopson/underscore-cli | npm install -g underscore-cli
#
# Usage: 
# jira                           Opens a new issue
# jira ABC-123                   Opens issue with key ABC-123
# jira -c ABC-123                Displays comments on issue ABC-123
# jira -c ABC-123 'a comment'    Writes comment to ABC-123
# jira -l                        List Issues. Optional Filtering: 
#                                -a: assigned to me
#                                -A john: assigned to john
#                                -S open: status is open
#                                -P ABC: project is ABC"
# jira -s                        Excute JQL to search for issues
# jira -f                        List favorite filters
# jira -f 10001                  Executes favorite filter. Takes filter Id
# jira -stat                     Retrieve list of avalible statuses

open_jira_issue () {
  
  #set cmd to open browser
  local open_cmd
  if [[ $(uname -s) == 'Darwin' ]]; then
    open_cmd='open'
  else
    open_cmd='xdg-open'
  fi

  if

  #check for dependancies
  node=$(program_is_installed node)
  underscore=$(program_is_installed underscore)
  if [[ $node = 0 || $underscore = 0 ]]; then
    echo "Missing Dependencies:"
    echo "Nodejs: $node"
    echo "underscore-cli: $underscore"
    return 0
  fi

  #Env vars for jira config
  if [ -f .jira-url ]; then
    jira_url=$(cat .jira-url)
  elif [ -f ~/.jira-url ]; then
    jira_url=$(cat ~/.jira-url)
  elif [[ "x$JIRA_URL" != "x" ]]; then
    jira_url=$JIRA_URL
  else
    echo "JIRA url is not specified anywhere."
    return 0
  fi

  if [ -f .jira-user ]; then
    jira_user=$(cat .jira-user)
  elif [ -f ~/.jira-user ]; then
    jira_user=$(cat ~/.jira-user)
  elif [[ "x$JIRA_USER" != "x" ]]; then
    jira_user=$JIRA_USER
  else
    echo "JIRA User is not specified anywhere."
    return 0
  fi

  if [ -f .jira-pass ]; then
    jira_pass=$(cat .jira-pass)
  elif [ -f ~/.jira-pass ]; then
    jira_pass=$(cat ~/.jira-pass)
  elif [[ "x$JIRA_PASS" != "x" ]]; then
    jira_pass=$JIRA_PASS
  else
    echo "JIRA Pass is not specified anywhere."
    return 0
  fi

  #API Constants
  local auth=$JIRA_USER:$JIRA_PASS
  local api_endpoint=$jira_url/rest/api/2

  #Command Switch
  case $1 in
    -l)
      echo "Retrieving Issues..." >&2
      while getopts "laA:S:P:" opt; do
        case $opt in
          a)
            assignee=$JIRA_USER
            echo "Assignee: $JIRA_USER" >&2
            ;;
          A)
            assignee=$OPTARG
            echo "Assignee: $OPTARG" >&2
            ;;
          S)
            state=$OPTARG
            echo "Status: $OPTARG" >&2
            ;;
          P)
            project=$OPTARG
            echo "Project: $OPTARG" >&2
            ;;
          \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
        esac
      done
      jql=jql\=
      if [[ ! -z "$assignee" ]]; then
        jql+=assignee\=$assignee
      fi
      if [[ ! -z "$state" ]]; then
        t="${jql: -1}"
        if [[ $t == "=" ]]; then
          jql+="status=$state"
        else
          jql+="+AND+status=\"$state\""
        fi
      fi
      if [[ ! -z "$project" ]]; then
        t="${jql: -1}"
        if [[ $t == "=" ]]; then
          jql+="project=$project"
        else
          jql+="+AND+project=$project"
        fi
      fi
      jql+=+order+by+duedate+asc
      response=$(curl -s -u $auth $api_endpoint/search\?$jql)
      errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
      issues=$(underscore --data "$response" extract 'issues' 2>/dev/null)
      
      if [[ ! -z "$errors" ]]; then
        output_errors $errors
      else
        output_issues $issues
      fi
    ;;
    -s)
      search $2
    ;;
    -c)
      if [ -z "$2" ]; then
        echo "Please specify an issue for commenting"
      else
        if [ -z "$3" ]; then
          echo "Retrieving comments"
          response=$(curl -s -u $auth $api_endpoint/issue/$2/comment)
          errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
          comments=$(underscore --data "$response" extract 'comments' 2>/dev/null)
        
          if [[ ! -z "$errors" ]]; then
            output_errors $errors
          else
            output_comments $comments
          fi
          # response=$(curl -s -u $auth $api_endpoint/issue/$2/comment?jql=maxResults=5 | underscore extract 'comments')
          # output_comments $response
        else
          comment=$(curl -s -u $auth -X POST --data '{"body": "'$3'"}' -H "Content-Type: application/json" $api_endpoint/issue/$2/comment | underscore select .body --outfmt text)
          echo "comment posted to $2: $comment"
        fi
      fi
    ;;
    -f)
      if [ -z "$2" ]; then
        echo "Retrieving filters"
        filters=$(curl -s -u $auth $api_endpoint/filter/favourite)
        output_filters $filters
      else
        response=$(curl -s -u $auth $api_endpoint/filter/$2)
        jql=$(underscore --data "$response" select ".jql" --outfmt text)
        search $jql
      fi
    ;;
    -stat)
      echo "Retrieving Status"
      response=$(curl -s -u $auth $api_endpoint/status)
      output_status $response
    ;;
    -h)
      usage
    ;;
    "")
      echo "Opening new issue"
      $open_cmd "$jira_url/secure/CreateIssue!default.jspa"
    ;;
    *)
      echo "Opening issue #$1"
      if [[ "x$JIRA_RAPID_BOARD" = "xtrue" ]]; then
        $open_cmd  "$jira_url/issues/$1"
      else
        $open_cmd  "$jira_url/browse/$1"
      fi
    ;;
 esac
}

  #global colors for output
  textreset=$(tput sgr0) # reset the foreground colour
  red=$(tput setaf 1)
  yellow=$(tput setaf 2)

usage()
{
echo "
${red}jira${textreset}                           :Opens a new issue
${red}jira ABC-123${textreset}                   :Opens issue with key ABC-123
${red}jira -c ABC-123${textreset}                :Displays comments on issue ABC-123
${red}jira -c ABC-123 'a comment'${textreset}    :Writes comment to ABC-123
${red}jira -l${textreset}                        :List Issues. Optional Filtering: 
  ${yellow}-a${textreset}      : assigned to me
  ${yellow}-A john${textreset} : assigned to john
  ${yellow}-S open${textreset} : status is open
  ${yellow}-P ABC${textreset}  : project is ABC
${red}jira -s${textreset}                         :Excute JQL to search for issues
${red}jira -f${textreset}                         :List favorite filters
${red}jira -f 10001${textreset}                   :Executes favorite filter. Takes filter Id
${red}jira -stat${textreset}                      :Retrieve list of avalible statuses"

}

search(){
  if [ -z "$1" ]; then
    echo "Please specify JQL to execute"
  else
    jql=jql\=
    jql+="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1")"
    response=$(curl -s -u $auth $api_endpoint/search\?$jql)
    errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
    issues=$(underscore --data "$response" extract 'issues' 2>/dev/null)
    
    if [[ ! -z "$errors" ]]; then
      output_errors $errors
    else
      output_issues $issues
    fi
  fi
}

output_errors(){
  echo "${red}ERROR(s):\t${textreset}$1"
}

output_issues(){
    keys=$(underscore --data "$1" pluck key --outfmt text)
    
    keyArr=()
    while read -r line; do
      keyArr+=("$line")
    done <<< "$keys"
    
    summaries=$(underscore --data "$1" select .summary --outfmt text)
    
    sumArr=()
    while read -r line; do
      sumArr+=("$line")
    done <<< "$summaries"

    priorities=$(underscore --data "$1" select ".priority .name" --outfmt text)

    priorityArr=()
    while read -r line; do
      priorityArr+=("$line")
    done <<< "$priorities"

    for ((i=0;i<${#keyArr[@]};i++));
    do
      echo "${yellow}${keyArr[i+1]}\t${red}${priorityArr[i+1]}\t${textreset}${sumArr[i+1]}" | column -s $'\t';
    done
}

output_comments(){
    bodies=$(underscore --data "$1" pluck body | underscore map 'value.replace(/\r?\n|\r/g,"")' --outfmt text 2>/dev/null)
    
    bodyArr=()
    while read -r line; do
      bodyArr+=("$line")
    done <<< "$bodies"
    
    authors=$(underscore --data "$1" select ".author .name" --outfmt text)
    
    authorArr=()
    while read -r line; do
      authorArr+=("$line")
    done <<< "$authors"

    for ((i=0;i<${#bodyArr[@]};i++));
    do
      echo "${yellow}----${red}${authorArr[i+1]}${yellow}----${textreset}"
      echo "${bodyArr[i+1]}" #| column -s $'\t';
    done
}

output_filters(){
    names=$(underscore --data "$1" pluck name --outfmt text)
    
    nameArr=()
    while read -r line; do
      nameArr+=("$line")
    done <<< "$names"
    
    ids=$(underscore --data "$1" pluck id --outfmt text)
    
    idArr=()
    while read -r line; do
      idArr+=("$line")
    done <<< "$ids"

    for ((i=0;i<${#nameArr[@]};i++));
    do
      echo "${yellow}${nameArr[i+1]}\t${textreset}${idArr[i+1]}" | column -s $'\t';
    done
}

output_status(){
  stats=$(underscore --data "$1" pluck name --outfmt text)

    statsArr=()
    while read -r line; do
      statsArr+=("$line")
    done <<< "$stats"

    for ((i=0;i<${#statsArr[@]};i++));
    do
      echo "${yellow}${statsArr[i+1]}" | column -s $'\t';
    done
}

#functions to check for node dependancies
#taken from: https://gist.github.com/JamieMason/4761049

# return 1 if global command line program installed, else 0
# example
# echo "node: $(program_is_installed node)"
function program_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  type $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

# return 1 if local npm package is installed at ./node_modules, else 0
# example
# echo "gruntacular : $(npm_package_is_installed gruntacular)"
function npm_package_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  ls node_modules | grep $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

alias jira='open_jira_issue'
