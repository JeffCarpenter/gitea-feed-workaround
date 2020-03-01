Gitea Feed Workaround Script
============================

A relatively simple workaround that generates RSS feeds for commits, 
releases, and issues on Gitea. 

####FEATURES

- Generates feeds for commits, releases, and issues
- Restricts feeds based on the repository visibility
- Supports arbitrary in-band announcements 
- Very configurable and easily modifiable


####CAVEATS

- Computationally inefficient, likely will scale poorly with 
  repository count
- Only sqlite3-based installations are supported (other databases 
  are possible with tinkering)
- Only GNU/Linux was considered. 
- No localization support


####HOW TO INSTALL

1. Copy gitea-feed-workaround.sh to a persistent location. 
2. Edit the variables at the beginning of `gitea-feed-workaround.sh`.
   Variables should reflect the configuration of your specific gitea 
   setup.
3. Run the script or install it as a system service.

At this point, the script should start generating feeds at the 
configured location. Assuming you've used the default FEEDS_URL 
slug (i.e. `/_feeds/`), the feeds for USER's REPOSITORY are 
located at `/_feeds/USER/REPOSITORY/{commits,issues,releases}.rss`.

Note that the script will need a longer amount of time for larger 
Gitea installations.

####HOW IT WORKS

This script works by periodically polling Gitea's databases 
for recent updates. These updates are then aggregated into static `.rss` 
files that can be hosted by Gitea's internal static server or a 
dedicated http server.

The definition of update depends on the represented resource:

* Commits (`commits.rss`): Any new commit is considered a new update.
* Issues (`commits.rss`): Any change to any issue is considered an 
  update; i.e some issues may appear multiple times in a single feed.
* Releases (`releases.rss`): Any new release or pre-release is 
  considered an update.
* Announcements (`*.rss`): Every announcement is considered an 
  update.
  
Aside from announcements, updates are sorted from newest to oldest 
and only a certain number of the newest updates are included in the
final feed.

The format used to express updates is version 2.0 of the RSS 
standard. RSS was chosen in favor of ATOM due to the lack of TTL 
support in the later.


####FEEDS MENU UI

If you want to add a "Feeds" tab to each repository page, copy 
or append `extra_tabs.tmpl` to the correct location. See the comments 
at the top of the file for more information. 


####FEED ANNOUNCEMENTS

Announcements are special feed entries that are pinned in all 
generated feeds. They are derived from files stored in the 
announcements directory (ANNOUNCEMENT_DIR):

* The title of the announcement is derived from the name of the file. 
* The content of the announcement are derived from the content of 
  the file. Only plain text content is supported.
* The date of the announcement is derived from the last modification 
  date (as reported by the underlying filesystem).

Announcements are always included in every single feed. They persist 
until their source files are removed from the announcements
directory.


####UPGRADE PATH TO NATIVE GITEA FEEDS

When Gitea eventually introduces feed support, you can announce the 
locations of the new feeds and the migration period via Feed 
Announcements.


####COMMERCIAL SUPPORT

Commercial integration support is available. Please send inquires to 
contact@ka.com.kw


####BUGS AND SOURCE CODE

The source code of this project is maintained in a git repository 
at code.ka.com.kw. Bug reports and features request are welcome 
there. You can visit this repository at: 
https://code.ka.com.kw/miscellaneous/gitea-feed-workaround

Alternatively, you can report bugs to support@ka.com.kw


####LICENSE

Files in this repository are available under the LGPLv3.


####COPYRIGHT

(ح) حقوق المؤلف محفوظة لشركة كوتوميتا لبرمجة وتشغيل الكمبيوتر وتصميم 
وإدارة مواقع الإنترنت (ش.ش.و) - سنة ٢٠٢٠

تنفي الشركة أي مسئولية عن عدم أهلية البرنامج لأداء وظيفته المعلن عنها 
أو عن الأضرار التي قد يتكبدها المستخدم وغيره نتيجة استخدام هذا 
البرنامج. تقع مسؤولية أي ضرر ناجم عن استخدام هذا البرنامج على عاتق 
المستخدم وحده. اطلع على المستندات المرافقة لهذا البرنامج لمزيد من 
المعلومات.

Copyright © 2020 Kutometa SPC, Kuwait
All rights reserved. Unless explicitly stated otherwise, this program 
is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE 
WARRANTY OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
See accompanying documentation for more details.

