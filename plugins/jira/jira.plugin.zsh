# To use: add a .jira-url file in the base of your project
#         You can also set JIRA_URL in your .zshrc or put .jira-url in your home directory
#         .jira-url in the current directory takes precedence
#
# If you use Rapid Board, set:
#JIRA_RAPID_BOARD="true"
# in you .zshrc
#
# Setup: cd to/my/project
#        echo "https://name.jira.com" >> .jira-url
# Usage: jira           # opens a new issue
#        jira ABC-123   # Opens an existing issue
open_jira_issue () {
  local open_cmd
  if [[ $(uname -s) == 'Darwin' ]]; then
    open_cmd='open'
  else
    open_cmd='xdg-open'
  fi

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
    if [[ $1 == "-l" ]]; then
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
          jql+="+AND+status=$state"
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
      response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?$jql)
      errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
      issues=$(underscore --data "$response" extract 'issues' 2>/dev/null)
      
      if [[ ! -z "$errors" ]]; then
        output_errors $errors
      else
        output_issues $issues
      fi

  elif [[ $1 == "-la" ]]; then
    if [ -z "$2" ]; then
      assignee=$JIRA_USER
    else
      assignee=$2
    fi
    echo "Retrieving Issues assigned to $assignee"
    response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?jql\=assignee\=$assignee+order+by+duedate+asc | underscore extract 'issues') # > response.tmp
    output_issues $response

  elif [[ $1 == "-lp" ]]; then
    if [ -z "$2" ]; then
      echo "Please specify a project key"
    else
      echo "Retrieving Issues from project $2"
      response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?jql\=project\=$2+order+by+duedate+asc | underscore extract 'issues')
      output_issues $response
    fi
  elif [[ $1 == "-c" ]]; then
    if [ -z "$2" ]; then
      echo "Please specify an issue for commenting"
    else
      if [ -z "$3" ]; then
        echo "Retrieving comments"
        response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/issue/$2/comment)
        errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
        comments=$(underscore --data "$response" extract 'comments' 2>/dev/null)
      
        if [[ ! -z "$errors" ]]; then
          output_errors $errors
        else
          output_comments $comments
        fi
        # response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/issue/$2/comment?jql=maxResults=5 | underscore extract 'comments')
        # output_comments $response
      else
        comment=$(curl -s -u $JIRA_USER:$JIRA_PASS -X POST --data '{"body": "'$3'"}' -H "Content-Type: application/json" $jira_url/rest/api/2/issue/$2/comment | underscore select .body --outfmt text)
        echo "comment posted to $2: $comment"
      fi
    fi
  elif [ -z "$1" ]; then
    echo "Opening new issue"
    $open_cmd "$jira_url/secure/CreateIssue!default.jspa"
  else
    echo "Opening issue #$1"
    if [[ "x$JIRA_RAPID_BOARD" = "xtrue" ]]; then
      $open_cmd  "$jira_url/issues/$1"
    else
      $open_cmd  "$jira_url/browse/$1"
    fi
  fi
}

  #global colors for output
  textreset=$(tput sgr0) # reset the foreground colour
  red=$(tput setaf 1)
  yellow=$(tput setaf 2)

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
    echo $1 > test.tmp
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

alias jira='open_jira_issue'
