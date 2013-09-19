Integrations
============
*Documentation, scripts, and sample files related to integrating Expensify into external ecosystems.*

Who this document is for
------------------------
This is a technical resource for developers and advanced finance teams to perform a low-level integration of Expensify into their back-end accounting framework.  This is for anybody looking to integrate Expensify with the following systems:

* Oracle (AP, iExpense)
* SAP
* Any file-based (CSV, XML, etc) import/export system

For general information about Expensify, please see <http://help.expensify.com>, or email <help@expensify.com>.

Export File Integration Overview
--------------------------------
The general flow of an integration is:

1. Create a directory (eg, "/expensify") on either a desktop or server computer.

2. Clone this repository to that directory using:

        git clone git@github.com:Expensify/Integrations.git

3. This will cause the repository to be cloned to an "Integrations" subdirectory (eg, "/expensify/Integrations").

4. Rename your copy of creds.sh to something more meaningful (eg, "/root/expensify_creds.sh") and enter your unique account information.  Create your account credentials at <https://www.expensify.com/tools/integrations/>.
    * *partnerUserID* -  Your unique identifier
    * *partnerUserSecret* - Treat this as you would a very secure password

5. Choose to where you would like the export file downloaded (eg, "/tmp").

6. Execute expensify_export.sh while providing the location to your credentials file, output directory, and desired template:

        ./expensify_export.sh -c /root/expensify_creds.sh -F /tmp/exportfile -t templates/everything_csv.fm

7. This will generate a request to the Expensify integration server to download a complete list of all expenses accessible by the configured user, and download into the output directory.

8. This script will "block" until the request completes, which depending on the request size might take many minutes.

9. Upon completion, the script will output the filename of the newly downloaded file to STDOUT.

10. This file can be manually uploaded to your accounting system, or perhaps post-processed in Excel or with code that you write.

11. This whole process is intended to be automated using something like "cron" such that the whole operation happens periodically (eg, nightly).


Structure of this repository
----------------------------
This GitHub repo contains the following high level resources:

    /README.md - This file
    /creds.sh - Template credential file
    /expensify_export.sh - Core automation utility
    /IntegrationsFileFlowchart.png - Illustration of typical API flow
    /templates/ - Directory containing FreeMarker templates
        everything_csv.fm - Creates a basic CSV containing everything

Output format
-------------
This system will output a CSV file containing the following columns:

* *reportID* -
* *accountID* -
* *reportName* -
* *managerID* -
* *managerEmail* -
* *accountEmail* -
* *created* -
* *total* -
* *status* -
* *state* -
* *submitted* -
* *currency* -
* *tag* -
* *approved* -
* *expense.transactionID* -
* *expense.unverified* -
* *expense.cardID* -
* *expense.reportID* -
* *expense.mcc* -
* *expense.tag* -
* *expense.currency* -
* *expense.billable* -
* *expense.amount* -
* *expense.inserted* -
* *expense.reimbursable* -
* *expense.details* -
* *expense.currencyConversionRate* -
* *expense.created* -
* *expense.modifiedAmount* -
* *expense.bank* -
* *expense.receiptID* -
* *expense.receiptFilename* -
* *expense.modifiedCreated* -
* *expense.merchant* -
* *expense.externalID* -
* *expense.convertedAmount* -
* *expense.modified* -
* *expense.category* -
* *expense.modifiedMerchant* -
* *expense.comment* -
* *expense.cardNumber* -
* *expense.transactionHash* -
* *expense.modifiedMCC* -
* *expense.receiptObject.thumbnail* -
* *expense.receiptObject.smallThumbnail* -
* *expense.receiptObject.formattedCreated* -
* *expense.receiptObject.state* -
* *expense.receiptObject.formattedMerchant* -
* *expense.receiptObject.transactionID* -
* *expense.receiptObject.type* -
* *expense.receiptObject.receiptID* -
* *expense.receiptObject.formattedAmount* -
* *expense.receiptObject.url* -
* *expense.categoryGlCode* -
* *expense.categoryPayrollCode* -
* *expense.tagGlCode* -
* *expense.hasTax* -
* *expense.taxRate* - set only if *expense.hasTax* is `true`
* *expense.taxAmount* - set only if *expense.hasTax* is `true`
* *report.managerPayrollID* -
* *report.submitterPayrollID* -
* *report.policyName* -

Custom output formats
---------------------
This system is designed to be incredibly customizable.  Should you need the output formatted into a different format, please contact <help@expensify.com>.
