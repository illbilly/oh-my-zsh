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

open_jira_issue () {
  
  #set cmd to open browser
  local open_cmd
  if [[ $(uname -s) == 'Darwin' ]]; then
    open_cmd='open'
  else
    open_cmd='xdg-open'
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
      response=$(curl -s -u $auth $api_endpoint/search\?$jql)
      errors=$(underscore --data "$response" select .errorMessages --outfmt text 2>/dev/null)
      issues=$(underscore --data "$response" extract 'issues' 2>/dev/null)
      
      if [[ ! -z "$errors" ]]; then
        output_errors $errors
      else
        output_issues $issues
      fi
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
${red}jira${textreset}                           Opens a new issue
${red}jira ABC-123${textreset}                   Opens issue with key ABC-123
${red}jira -c ABC-123${textreset}                Displays comments on issue ABC-123
${red}jira -c ABC-123 'a comment'${textreset}    Writes comment to ABC-123
${red}jira -l${textreset}                        List Issues. Optional Filtering: 
                               -a: assigned to me
                               -A john: assigned to john
                               -S open: status is open
                               -P ABC: project is ABC"

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
