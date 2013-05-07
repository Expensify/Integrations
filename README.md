Integrations
============
*Documentation, scripts, and sample files related to integrating Expensify into external ecosystems.*

Who this document is for
------------------------
This is a technical resource for developers and advanced finance teams to perform a low-level integration of Expensify into their back-end accounting framework.  This is for anybody looking to integrate Expensify with the following systems:

* Oracle (AP, iExpense)
* SAP
* Intaact
* NetSuite
* Xero
* SAP
* Any file-based (CSV, XML, etc) import/export system

For general information about Expensify, please see http://help.expensify.com, or email help@expensify.com.

Integration overview
--------------------
The general flow of an integration is:

1. Create a directory (eg, "/expensify") on the computer to which you would like to download the export file

2. Clone this repository to that directory using:

    git checkout git@github.com:Expensify/Integrations.git

3. This will cause the repository to be cloned to an "Integrations" subdirectory (eg, "/expensify/Integrations")

4. Copy the template_expensify_creds.sh file someplace secure (eg, "/root"), and reduce permissions to the minimum (eg, chmod 0400)

5. Rename your copy of template_expensify_creds.sh to something more meaningful (eg, "/root/expensify_creds.sh") and enter your unique account information:  (Write help@expensify.com to obtain this.)
    * partnerName - Typically the domain name of your company
    * parnterSecret - A random secret key assigned to you
    * email - Email address of the account as which to authenticate
    * partnerUserSecret - Password of the user account

6. Choose to where you would like the export file downloaded (eg, "/tmp")

7. Execute expensify_export.sh while providing the location to the "expensify_creds.sh" and output directory:

    ./expensify_export.sh /root/expensify_creds.sh /tmp

8. This will generate a request to the Expensify integration server to download a complete list of all expenses accessible by the configured user, and download into the output directory

9. This script will "block" until the request completes, which depending on the request size might take many minutes.

10. Upon completion, the script will output the filename of the newly downloaded file to STDOUT

11. This file can be manually uploaded to your accounting system, or perhaps post-processed in Excel or with code that you write.

12. This whole process is intended to be automated using something like "cron" such that the whole operation happens periodically (eg, nightly).


Structure of this repository
----------------------------
This GitHub repo contains the following high level resources:

    /README.md - This file
    /template_creds.sh - Template credential file
    /expensify_export.sh - Core automation utility

