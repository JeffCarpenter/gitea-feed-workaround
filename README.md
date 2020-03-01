Gitea Feed Workaround Script
============================

A relatively simple workaround that generates RSS feeds for commits, releases, and 
issues on Gitea. 

FEATURES
--------

- Generates feeds for commits, releases, and issues
- Restricts feeds based on the repository visibility
- Supports arbitrary in-band announcements 
- Very configurable and easily modifiable


CAVEATS
-------

- Computationally inefficient, likely will scale poorly with 
  repository count

- Only sqlite3-based installations are supported (other databases 
  are possible with tinkering)

- Only GNU/Linux was considered. 

- No localization support


HOW TO INSTALL
--------------

1. Copy gitea-feed-workaround.sh to a persistent location.
2. Edit the variables at the beginning of the script to reflect the 
   desired values.
3. Run the script manually, or add it as a system service.

At this point, the script should start generating feeds at the 
configured location.


FEEDS MENU UI
-------------

If you want to add a "Feeds" tab to each repository page, copy 
or append `extra_tabs.tmpl` to the correct location. See the comments 
at the top of the file for more information. 


FEED ANNOUNCEMENTS
------------------

This script supports arbitrary textual announcements that are 
broadcast on all generated feeds. 

To make an announcement, add a text file in the Announcement 
Directory (ANNOUNCEMENT_DIR). The title of the announcement is 
taken verbatim from the name of the file. The body of the 
announcement is derived from the contents of the file. The time of the 
announcement is taken from the modification time of the file.

Announcements persist until their files are removed.


UPGRADE PATH TO NATIVE GITEA FEEDS
----------------------------------

When Gitea eventually introduces feed support, you can announce the 
locations of the new feeds and the migration period via Feed 
Announcements.


SUPPORT
-------

Integration support is available. Please contact sales@ka.com.kw


BUGS AND SOURCE CODE
--------------------

The source code of this project is maintained in a git repository 
at code.ka.com.kw. Bug reports and features request are welcome 
there. You can visit this repository at:

    https://code.ka.com.kw/miscellaneous/gitea-feed-workaround


LICENSE
-------

Files in this repository are available under the LGPLv3.


COPYRIGHT
---------

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
