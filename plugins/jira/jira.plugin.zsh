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
  if [[ $1 == "-la" ]]; then
    if [ -z "$2" ]; then
      assignee=$JIRA_USER
    else
      assignee=$2
    fi
    echo "Retrieving Issues assigned to $assignee"
    IN=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?jql\=assignee\=$assignee+order+by+duedate+asc | json -e 'this.keys = []; for(var i = 0; i< issues.length; i++){keys.push(issues[i].key);}' keys -C)
    if [[ $IN == "evalmachine*" ]]; then
      echo "Failed to retrieve issues for $assignee"
    else
      keys=${IN//,/ }
      echo $keys
    fi

  elif [[ $1 == "-lp" ]]; then
    if [ -z "$2" ]; then
      echo "Please specify a project key"
    else
      echo "Retrieving Issues from project $2"
      IN=$(curl -s -u $JIRA_USER:$JIRA_PASS $jira_url/rest/api/2/search\?jql\=project\=$2+order+by+duedate+asc | json -e 'this.keys = []; for(var i = 0; i< issues.length; i++){keys.push(issues[i].key);}' keys -C)
      if [[ $IN == "evalmachine*" ]]; then
        echo "Failed to retrieve issues for project: $2"
      else
        keys=${IN//,/ }
        echo $keys
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

alias jira='open_jira_issue'
