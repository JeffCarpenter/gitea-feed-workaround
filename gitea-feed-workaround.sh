#!/bin/bash
#
# Copyright © 2020 Kutometa SPC, Kuwait
#
#  All rights reserved. Unless explicitly stated otherwise, this 
#  program is provided AS IS with NO WARRANTY OF ANY KIND, 
#  INCLUDING THE WARRANTY OF MERCHANTABILITY AND FITNESS FOR A 
#  PARTICULAR PURPOSE. 
#  
# See accompanying documentation for more details.
# www.ka.com.kw

set -euH

SITE_TITLE="TITLE"                      # Short Site Title

GITEA_HOST_URL="https://DOMAIN"         # app.ini/server/ROOT_URL   (User-visible base URL of Gitea)

GITEA_DB_PATH="..../data/gitea.db"      # app.ini/database/PATH     (Path to Gitea's sqlite3 DB)

GITEA_REPOSITORY_PATH="...."            # app.ini/repository/ROOT   

FEEDS_URL="https://DOMAIN/_feeds"       # User-visible base URL where feeds should be accessed
                                        # Feeds are accessed at FEEDS_URL/USER/REPOSITORY/FEED.rss
                                        
FEEDS_PATH="..../custom/public/_feeds"  # The root path where the feeds are stored. This path should
                                        # usually correspond to the public folder of your gitea 
                                        # installation
                                        
ANNOUNCEMENT_DIR="..../announcements"   # The directory where out-of-band announcements are read
INTERVAL="5"                            # The interval at which feeds are regenerated 

REPOSITORY_VISIBILITY="PUBLIC"          # Selects the type of repositories that are allowed to 
                                        # have feeds. Setting this variable to "PUBLIC"
                                        # only generates feeds for public repositories, and 
                                        # "PRIVATE" limits feeds to private repositories. Setting 
                                        # this variable to "ALL" generates feeds for all 
                                        # repositories.
                                        
ENABLE_COMMIT_FEED="YES"                # Generate Commit Feeds

ENABLE_RELEASE_FEED="YES"               # Generate Release Feeds

ENABLE_ISSUE_FEED="YES"                 # Generate Issue Feeds

ENABLE_GLOBAL_FEED_LISTS="NO"           # Generate Global feed lists

MAX_NUM_OF_ENTRIES="10"                 # Limit the number of feed entries (excluding announcements)

GITEA_VERSION="AUTODETECT"              # Sets how gitea's database should be accessed. If set to
                                        # AUTODETECT, this script will attempt to obtain this 
                                        # information by executing 'gitea --version'


#--------------------------------------------------------------------

VERSION=0.7
echo "Gitea Feed Workaround Daemon
Version $VERSION

Copyright © 2020 Kutometa SPC, Kuwait
All rights reserved. Unless explicitly stated otherwise, this program 
is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE 
WARRANTY OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
See accompanying documentation for more details.

Configuration
-------------

Refresh Interval:       $INTERVAL minutes
Gitea Domain:           $GITEA_HOST_URL
RSS URL Prefix:         $FEEDS_URL
Gitea DB path:          $GITEA_DB_PATH
Gitea Repository Path:  $GITEA_REPOSITORY_PATH
Output Feed Dir:        $FEEDS_PATH

---------------------------------------------------------------------
"



escape_url() {
    xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g'
}
escape_xml() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

update_if_different() {
    if ! cmp -s "$2" "/proc/self/fd/0" < <(echo "$1") ; then
        echo "$1" > "$2"
    fi
}

# first arg must be a timestamp
gen_lastbuilddate() {
    if [[ -d "$ANNOUNCEMENT_DIR" ]]; then
        LATEST_TIMESTAMP="$1"
        while read -r announcement; do
            POSSIBLE_DATE="$(stat -c '%Y' "$ANNOUNCEMENT_DIR/$announcement")"
            if [[ "$POSSIBLE_DATE" -gt "$LATEST_TIMESTAMP"  ]]; then
                LATEST_TIMESTAMP="$POSSIBLE_DATE"
            fi
        done < <(ls "$ANNOUNCEMENT_DIR")
        echo "<lastBuildDate>$(date -R -d "@$LATEST_TIMESTAMP" | escape_xml)</lastBuildDate>"
    else
        echo "<lastBuildDate>$(date -R -d "@$1" | escape_xml)</lastBuildDate>"
    fi
}

inject_announcements() {
    if [[ -d "$ANNOUNCEMENT_DIR" ]]; then
        while read -r announcement; do
            XML_DATE="$(date -R -d "@$(stat -c '%Y' "$ANNOUNCEMENT_DIR/$announcement")" | escape_xml)"
            XML_TITLE="$(echo "$announcement" | escape_xml)"
            URL_TITLE="$(echo "$announcement" | escape_url)"
            XML_BODY="$(cat "$ANNOUNCEMENT_DIR/$announcement" | escape_xml)"
            
            echo "<item>
                <title>Announcement: $XML_TITLE</title>
                <guid isPermaLink='false'>$GITEA_HOST_URL#announcement-$URL_TITLE</guid>
                <pubDate>$XML_DATE</pubDate>
                <description>$XML_BODY</description>
            </item>" 
        done < <(ls "$ANNOUNCEMENT_DIR")
    fi
}

assert_dep() {
    if ! which "$1" >/dev/null 2>/dev/null; then
        echo "[gitea-feed-workaround] --X-- '$1' was not found. '$1' is required for this script to function. Aborting."
        exit 1
    fi
}

assert_dep "sqlite3"
assert_dep "tail"
assert_dep "head"
assert_dep "cut"
assert_dep "stat"
assert_dep "xxd"
assert_dep "sed"
assert_dep "cmp"
assert_dep "date"
assert_dep "git"

if [[ "$GITEA_VERSION" == "AUTODETECT" ]]; then
    GITEA_VERSION="$(gitea --version | tail -c +15 | cut -d ' ' -f 1)"
fi

# Define queries based on the version of gitea used.
# [[ "$GITEA_VERSION" == "1.10.3" ]]
if true; then # all versions of gitea
    # Evironment Variables Used
    #   $SQLITE_CRIT    : Appended directly after the query
    #   $GITEA_DB_PATH  : Path to gitea's sqlite db file
    # Feilds 
    #   1. Case-sensitive Name of repository owner
    #   2. Case-sensitive Name of repository
    #   3. Repository Description
    #   4. Repository ID
    # Delimiters
    #   Columns : U+1D
    #   Rows    : U+1E
    query_repo_list() {
        sqlite3 "$GITEA_DB_PATH" <<COMMANDS
.separator $(printf '\x1d') $(printf '\x1e') 
select replace(replace(user.name, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''), 
       replace(replace(repository.name, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''), 
       replace(replace(repository.description, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(repository.id, '$(printf '\x1d')', ''), '$(printf '\x1e')', '')
       from repository 
       inner join user on repository.owner_id = user.id$SQLITE_CRIT
COMMANDS
    }
    
    # Returns a list of releases associated with a given repository
    #
    # Evironment Variables Used
    #   $SQLITE_CRIT    : Appended directly after the query
    #   $REPO_ID        : Repository ID
    #   $MAX_NUM_OF_ENTRIES: Number of entries included 
    # Feilds 
    #   1. Case-sensitive Release Tag
    #   2. Case-sensitive Release Title
    #   3. Release Note
    #   4. Is draft
    #   5. Is prerelease
    #   6. Release/Tag Timestamp
    # Delimiters
    #   Columns : U+1D
    #   Rows    : U+1E
    query_release_list() {
        sqlite3 "$GITEA_DB_PATH" <<RELEASES
.separator $(printf '\x1d') $(printf '\x1e') 
select replace(replace(release.tag_name, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''), 
       replace(replace(release.title, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''), 
       replace(replace(release.note, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(release.is_draft, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(release.is_prerelease, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(release.created_unix, '$(printf '\x1d')', ''), '$(printf '\x1e')', '')
       from release where repo_id=$REPO_ID ORDER BY release.created_unix DESC LIMIT $MAX_NUM_OF_ENTRIES
RELEASES
    }
    
    # Returns a list of issues associated with a given repository
    #
    # Evironment Variables Used
    #   $SQLITE_CRIT    : Appended directly after the query
    #   $REPO_ID        : Repository ID
    #   $MAX_NUM_OF_ENTRIES: Number of entries included 
    # Feilds 
    #   1. Issue Index Number
    #   2. Issue Title
    #   3. Issue Content
    #   4. Update Timestamp
    # Delimiters
    #   Columns : U+1D
    #   Rows    : U+1E
    query_issues_list() {
        sqlite3 "$GITEA_DB_PATH" <<ISSUES
.separator $(printf '\x1d') $(printf '\x1e') 
select replace(replace(issue."index", '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(issue.name, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(issue.content, '$(printf '\x1d')', ''), '$(printf '\x1e')', ''),
       replace(replace(issue.updated_unix, '$(printf '\x1d')', ''), '$(printf '\x1e')', '')
       FROM issue WHERE repo_id=$REPO_ID ORDER BY issue.updated_unix DESC LIMIT $MAX_NUM_OF_ENTRIES
ISSUES
    }    
fi

if [[ "$REPOSITORY_VISIBILITY" == "ALL" ]]; then
    SQLITE_CRIT=""
elif [[ "$REPOSITORY_VISIBILITY" == "PUBLIC" ]]; then
    SQLITE_CRIT=" where repository.is_private=0"
elif [[ "$REPOSITORY_VISIBILITY" == "PRIVATE" ]]; then
    SQLITE_CRIT=" where repository.is_private=1"
else
    echo '* $REPOSITORY_VISIBILITY must be ALL, PUBLIC, or PRIVATE. '"'$REPOSITORY_VISIBILITY' found."
    exit 1
fi

INITIAL_SLEEP=0
while true; do
    if [[ "$INITIAL_SLEEP" == "0" ]]; then
        INITIAL_SLEEP="1"
    else
        echo "[gitea-feed-workaround] Sleeping for $INTERVAL minutes"
        sleep "$INTERVAL"m
    fi
    echo "[gitea-feed-workaround] Regenerating feeds for $GITEA_HOST_URL"
    GLOBAL_URL_LIST=""
    COMMIT_OPML_LIST=""
    RELEASE_OPML_LIST=""
    ISSUE_OPML_LIST=""
    while read -d "$(printf '\x1e')" -r REPOSITORY_LINE; do
        OIFS="$IFS"
        IFS=$(printf '\x1d')
        STUFF=($REPOSITORY_LINE);
        IFS="$OIFS"
            
        if [[ "${#STUFF[@]}" != "4" ]]; then
            echo "[gitea-feed-workaround] --X-- Error: ${#STUFF[@]} results obtained instead of 4"
            break
        fi
        
        RAW_REPO_OWNER="${STUFF[0]}"
        RAW_REPO_NAME="${STUFF[1]}"
        RAW_REPO_DESC="${STUFF[2]}"
        
        PATH_REPO_OWNER="$RAW_REPO_OWNER"
        PATH_REPO_NAME="$RAW_REPO_NAME"
        
        PATH_REPO_OWNER_LOWER="$( echo -n "${STUFF[0]}" | tr '[:upper:]' '[:lower:]')" 
        PATH_REPO_NAME_LOWER="$( echo -n "${STUFF[1]}" | tr '[:upper:]' '[:lower:]')"
                
        URL_REPO_OWNER="$(echo -n "${STUFF[0]}" | escape_url)"
        URL_REPO_NAME="$(echo -n "${STUFF[1]}" | escape_url)"
        URL_REPO_DESC="$(echo -n "${STUFF[2]}" | escape_url)"
        REPO_ID="${STUFF[3]}"
        URL_REPOSITORY_PREFIX="$GITEA_HOST_URL/$URL_REPO_OWNER/$URL_REPO_NAME"
        URL_REPOSITORY_COMMIT_PREFIX="$GITEA_HOST_URL/$URL_REPO_OWNER/$URL_REPO_NAME/commit"
        
        
        if ! cd "$GITEA_REPOSITORY_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER.git"; then
            echo "[gitea-feed-workaround] Ignoring '$RAW_REPO_OWNER/$RAW_REPO_NAME' because '$GITEA_REPOSITORY_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER.git' does not exist."
            continue
        fi        
        
        # ***********************************************************
        # * --------------------------------------------------------
        # *                     COMMIT FEED
        # * --------------------------------------------------------
        # ***********************************************************
        if [[ "$ENABLE_COMMIT_FEED" != "YES" ]] || ! git log 2> /dev/null > /dev/null ; then
            echo "[gitea-feed-workaround] Commit feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' not generated (disabled or empty git repo @ '$GITEA_REPOSITORY_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER.git')."
        else
            RSS_FEED_STR=""
            #ATOM_FEED="$(mktemp)"
            
            #echo "<?xml version='1.0' encoding='utf-8'?>
            #   <feed xmlns='http://www.w3.org/2005/Atom'>
            #     <title>$(echo "$RAW_REPO_OWNER/$RAW_REPO_NAME Commits — $SITE_TITLE" | escape_xml)</title>
            #     <link href='$URL_REPOSITORY_PREFIX'/>
            #     <updated>$(git log -1 --pretty='format:%cI')</updated>
            #     <id>$URL_REPOSITORY_PREFIX#commits</id>
            #" > "$ATOM_FEED"
            XML_FEED_TITLE="$(echo -n "$RAW_REPO_OWNER/$RAW_REPO_NAME Commits — $SITE_TITLE" | escape_xml)"
            XML_FEED_DESC="$(echo -n "$RAW_REPO_DESC" | escape_xml)"
            
            RSS_FEED_STR="<?xml version='1.0' encoding='utf-8'?>
                <rss version='2.0'>
                    <channel>
                         <title>$XML_FEED_TITLE</title>
                         <description>$XML_FEED_DESC</description>
                         <link>$URL_REPOSITORY_PREFIX</link>
                         $(gen_lastbuilddate "$(git log -1 --pretty='format:%ct')")
                         <ttl>$INTERVAL</ttl>
            "
            
            while read -d '' -r ENTRY; do
                OIFS="$IFS"
                IFS=$(printf '\x1e')
                STUFF=($ENTRY);
                IFS="$OIFS"
                #STUFF=("${ENTRY[@]}" "");
                #echo "$ENTRY" | hd
                URL_COMMIT_HASH="$( echo -n ${STUFF[1]} | escape_url )"
                XML_COMMIT_SHORT_HASH="$(echo -n "${STUFF[1]}" | head -c 6 | escape_xml)..$(echo "${STUFF[1]}" | tail -c 7 | escape_xml)"
                XML_COMMIT_SUBJECT="$( echo -n "${STUFF[0]}" | escape_xml)"
                XML_COMMIT_AUTHOR="$( echo -n "${STUFF[2]}" | escape_xml)"
                XML_COMMIT_ISO_DATE="$( echo -n "${STUFF[3]}" | escape_xml )"
                XML_COMMIT_MAIL_DATE="$( date -R -d "${STUFF[3]}" )"
                XML_COMMIT_BODY="";
                if [[ "${#STUFF[@]}" -ge 5 ]]; then
                    XML_COMMIT_BODY="$( echo -n "${STUFF[4]}" | escape_xml)"
                fi
                
                #echo "<entry>
                #    <title>$XML_COMMIT_SUBJECT ($XML_COMMIT_SHORT_HASH)</title>
                #    <link href='$URL_REPOSITORY_COMMIT_PREFIX/$URL_COMMIT_HASH' />
                #    <id>$URL_REPOSITORY_COMMIT_PREFIX/$URL_COMMIT_HASH</id>
                #    <author><name>$XML_COMMIT_AUTHOR</name></author>
                #    <updated>$XML_COMMIT_ISO_DATE</updated>
                #    <summary>$XML_COMMIT_BODY</summary>
                #</entry>"  >> "$ATOM_FEED"
                
                RSS_FEED_STR="$RSS_FEED_STR
                <item>
                    <title>$XML_COMMIT_SUBJECT ($XML_COMMIT_SHORT_HASH)</title>
                    <link>$URL_REPOSITORY_COMMIT_PREFIX/$URL_COMMIT_HASH</link>
                    <guid isPermaLink='false'>$URL_REPOSITORY_COMMIT_PREFIX/$URL_COMMIT_HASH</guid>
                    <pubDate>$XML_COMMIT_MAIL_DATE</pubDate>
                    <description>$XML_COMMIT_BODY</description>
                </item>"
            done < <(git log -n "$MAX_NUM_OF_ENTRIES" -z --pretty="tformat:%s%x1E%H%x1E%an%x1E%aI%x1E%b" | cat)
            
            RSS_FEED_STR="$RSS_FEED_STR$(inject_announcements)"
            RSS_FEED_STR="$RSS_FEED_STR</channel></rss>"
            
            #echo "</feed>"  >> "$ATOM_FEED"
            
            
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER"
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME"
            update_if_different "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME/commits.rss"
            update_if_different "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/commits.rss"
            COMMIT_OPML_LIST="$COMMIT_OPML_LIST
                <outline title='$XML_FEED_TITLE' 
                         text='$XML_FEED_TITLE' 
                         description='$XML_FEED_DESC' 
                         type='rss' 
                         xmlUrl='$FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/commits.rss' 
                         htmlUrl='$URL_REPOSITORY_PREFIX'/>
            "
            GLOBAL_URL_LIST="$GLOBAL_URL_LIST
                             $FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/commits.rss"
            echo "[gitea-feed-workaround] Regenerated commit feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' at '$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/commits.rss'"
            #cp  "$ATOM_FEED" "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME/commits.atom"
            #mv  "$ATOM_FEED" "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/commits.atom"
            #echo "[gitea-feed-workaround] Regenerated commit feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' at '$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/commits.atom'"
        fi
        
        
        # ***********************************************************
        # * --------------------------------------------------------
        # *                     RELEASE FEED
        # * --------------------------------------------------------
        # ***********************************************************
        
        if [[ "$ENABLE_RELEASE_FEED" != "YES" ]]; then
            echo "[gitea-feed-workaround] Release feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' not generated (disabled)."
        else
            RSS_FEED_STR=""
            
            XML_FEED_TITLE="$(echo -n "$RAW_REPO_OWNER/$RAW_REPO_NAME Releases — $SITE_TITLE" | escape_xml)"
            XML_FEED_DESC="$(echo -n "$RAW_REPO_DESC" | escape_xml)"
            XML_FEED_HOME_URL="$URL_REPOSITORY_PREFIX/releases"
                         
            RSS_FEED_STR="<?xml version='1.0' encoding='utf-8'?>
                <rss version='2.0'>
                    <channel>
                         <title>$XML_FEED_TITLE</title>
                         <description>$XML_FEED_DESC</description>
                         <link>$XML_FEED_HOME_URL</link>
                         <ttl>$INTERVAL</ttl>
            "
            
            ADDED_LAST_BUILD_TAG="0"
            while read -d "$(printf '\x1e')" -r RELEASE_LINE; do
                OIFS="$IFS"
                IFS=$(printf '\x1d')
                STUFF=($RELEASE_LINE);
                IFS="$OIFS"
                URL_RELEASE_TAG_NAME="$( echo -n "${STUFF[0]}" | escape_url)"
                XML_RELEASE_TAG_NAME="$( echo -n "${STUFF[0]}" | escape_xml)"
                XML_RELEASE_TITLE="$( echo -n "${STUFF[1]}" | escape_xml)"
                XML_RELEASE_NOTE="$( echo -n "${STUFF[2]}" | escape_xml)"
                RAW_RELEASE_IS_DRAFT="${STUFF[3]}"
                RAW_RELEASE_IS_PRERELEASE="${STUFF[4]}"
                XML_RELEASE_MAIL_DATE="$(date -R -d "@${STUFF[5]}" | escape_xml)"
                RAW_RELEASE_DATE="${STUFF[5]}"
                
                if [[ "$RAW_RELEASE_IS_DRAFT" != "0" ]]; then continue; fi
                #if [[ "$RAW_RELEASE_IS_PRERELEASE" != "0" ]]; then continue; fi
                
                if [[ "$ADDED_LAST_BUILD_TAG" == "0" ]]; then
                    RSS_FEED_STR="$RSS_FEED_STR$(gen_lastbuilddate "$RAW_RELEASE_DATE")"  
                    ADDED_LAST_BUILD_TAG="1"
                fi
                
                RSS_FEED_STR="$RSS_FEED_STR
                <item>
                    <title>$XML_RELEASE_TITLE ($XML_RELEASE_TAG_NAME)</title>
                    <link>$URL_REPOSITORY_PREFIX/releases#$URL_RELEASE_TAG_NAME</link>
                    <guid isPermaLink='false'>$URL_REPOSITORY_PREFIX/releases#$URL_RELEASE_TAG_NAME</guid>
                    <pubDate>$XML_RELEASE_MAIL_DATE</pubDate>
                    <description>$XML_RELEASE_NOTE</description>
                </item>"
            done < <(query_release_list)
            
            RSS_FEED_STR="$RSS_FEED_STR$(inject_announcements)"
            RSS_FEED_STR="$RSS_FEED_STR</channel></rss>"
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER"
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME"
            update_if_different  "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME/releases.rss"
            update_if_different  "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/releases.rss"
            RELEASE_OPML_LIST="$RELEASE_OPML_LIST
                <outline title='$XML_FEED_TITLE' 
                         text='$XML_FEED_TITLE' 
                         description='$XML_FEED_DESC' 
                         type='rss' 
                         xmlUrl='$FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/releases.rss' 
                         htmlUrl='$XML_FEED_HOME_URL'/>
            "
            GLOBAL_URL_LIST="$GLOBAL_URL_LIST
                             $FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/releases.rss"
            echo "[gitea-feed-workaround] Regenerated commit feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' at '$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/releases.rss'"
        fi
        
        
        # ***********************************************************
        # * --------------------------------------------------------
        # *                     ISSUE FEED
        # * --------------------------------------------------------
        # ***********************************************************
        
        if [[ "$ENABLE_ISSUE_FEED" != "YES" ]]; then
            echo "[gitea-feed-workaround] Issue feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' not generated (disabled)."
        else
            RSS_FEED_STR=""
            
            XML_FEED_TITLE="$(echo -n "$RAW_REPO_OWNER/$RAW_REPO_NAME Issues — $SITE_TITLE" | escape_xml)"
            XML_FEED_DESC="$(echo -n "$RAW_REPO_DESC" | escape_xml)"
            XML_FEED_HOME_URL="$URL_REPOSITORY_PREFIX/issues"
            
            RSS_FEED_STR="<?xml version='1.0' encoding='utf-8'?>
                <rss version='2.0'>
                    <channel>
                         <title>$XML_FEED_TITLE</title>
                         <description>$XML_FEED_DESC</description>
                         <link>$XML_FEED_HOME_URL</link>
                         <ttl>$INTERVAL</ttl>
            "
            
            ADDED_LAST_BUILD_TAG="0"
            while read -d "$(printf '\x1e')" -r ISSUE_LINE; do
                OIFS="$IFS"
                IFS=$(printf '\x1d')
                STUFF=($ISSUE_LINE);
                IFS="$OIFS"
                URL_ISSUE_INDEX="$( echo -n "${STUFF[0]}" | escape_url)"
                XML_ISSUE_INDEX="$( echo -n "${STUFF[0]}" | escape_xml)"
                XML_ISSUE_TITLE="$( echo -n "${STUFF[1]}" | escape_xml)"
                XML_ISSUE_MODIFICATION_DATE="$(date -R -d "@${STUFF[3]}" | escape_xml)"
                RAW_ISSUE_DATE="${STUFF[3]}"
                URL_NOUNCE="$( echo -n "${STUFF[3]}" | escape_url)"
                #XML_ISSUE_BODY="$( echo -n "${STUFF[2]}" | escape_xml)"
                #<description>$XML_ISSUE_BODY</description>
                
                if [[ "$ADDED_LAST_BUILD_TAG" == "0" ]]; then
                    RSS_FEED_STR="$RSS_FEED_STR$(gen_lastbuilddate "$RAW_ISSUE_DATE")"  
                    ADDED_LAST_BUILD_TAG="1"
                fi
                
                RSS_FEED_STR="$RSS_FEED_STR
                <item>
                    <title>Issue #$XML_ISSUE_INDEX: $XML_ISSUE_TITLE</title>
                    <link>$URL_REPOSITORY_PREFIX/issues/$XML_ISSUE_INDEX#$URL_NOUNCE</link>
                    <guid isPermaLink='false'>$URL_REPOSITORY_PREFIX/issues/$XML_ISSUE_INDEX#$URL_NOUNCE</guid>
                    <pubDate>$XML_ISSUE_MODIFICATION_DATE</pubDate>
                </item>"
            done < <(query_issues_list)
            
            RSS_FEED_STR="$RSS_FEED_STR$(inject_announcements)"
            RSS_FEED_STR="$RSS_FEED_STR</channel></rss>"
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER"
            mkdir -p "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME"
            update_if_different "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER/$PATH_REPO_NAME/issues.rss"
            update_if_different "$RSS_FEED_STR" "$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/issues.rss"
            ISSUE_OPML_LIST="$ISSUE_OPML_LIST
                <outline title='$XML_FEED_TITLE' 
                         text='$XML_FEED_TITLE' 
                         description='$XML_FEED_DESC' 
                         type='rss' 
                         xmlUrl='$FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/issues.rss' 
                         htmlUrl='$XML_FEED_HOME_URL'/>
            "
            GLOBAL_URL_LIST="$GLOBAL_URL_LIST
                             $FEEDS_URL/$PATH_REPO_OWNER/$PATH_REPO_NAME/issues.rss"
            echo "[gitea-feed-workaround] Regenerated commit feed for '$RAW_REPO_OWNER/$RAW_REPO_NAME' at '$FEEDS_PATH/$PATH_REPO_OWNER_LOWER/$PATH_REPO_NAME_LOWER/issues.rss'"
        fi
    done < <(query_repo_list)
    
    if [[ "$ENABLE_GLOBAL_FEED_LISTS" != "YES" ]]; then
        echo "[gitea-feed-workaround] Global RSS OMPL is disabled."
    else
        OPML_LIST="<?xml version='1.0'?>
            <opml version='1.0'>
                <head>
                    <title>$SITE_TITLE</title>
                </head>
                <body>
                    <outline title='$SITE_TITLE Commits'  text='$SITE_TITLE Commits'  description='$SITE_TITLE Commits'  type='folder'>$COMMIT_OPML_LIST</outline>
                    <outline title='$SITE_TITLE Releases' text='$SITE_TITLE Releases' description='$SITE_TITLE Releases' type='folder'>$RELEASE_OPML_LIST</outline>
                    <outline title='$SITE_TITLE Issues'   text='$SITE_TITLE Issues'   description='$SITE_TITLE Issues'   type='folder'>$ISSUE_OPML_LIST</outline>
                </body>
            </opml>"
        mkdir -p "$FEEDS_PATH/all"
        update_if_different "$OPML_LIST"       "$FEEDS_PATH/all/feeds.opml"
        update_if_different "$(echo "$GLOBAL_URL_LIST" | awk '{$1=$1};1' | sed '/^$/d')" "$FEEDS_PATH/all/feeds.txt"
    fi
done

