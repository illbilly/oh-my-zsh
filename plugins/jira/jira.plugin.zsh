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
  issuesExec="this.items=[];for(var i=0;i<issues.length;i++){var obj=new Object;obj.summary=issues[i].fields.summary;obj.key=issues[i].key;items.push(obj)}"
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
    if [[ $1 == "-ls" ]]; then
      if [ -z "$2" ]; then
        echo "please provide the status you wish to retrieve"
      else
        echo "Retrieve Issues with status: $2"
        response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?jql\=status\=$2+order+by+duedate+asc | underscore extract 'issues') # > response.tmp
        output_issues $response
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
        response=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/issue/$2/comment?jql=maxResults=5 | underscore extract 'comments')
        output_comments $response
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
    bodies=$(underscore --data "$1" pluck body | underscore map 'value.replace(/\r?\n|\r/g,"")' --outfmt text)
    
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
