# WSUSScripts
A collection of scripts to perform maintenance on WSUS.

You can run these individually, or just run maintenance.ps1

I created this for automatic regular maintenance in my environment.  hopefully someone finds this useful.

The scripts are commented, please read through once before running in your environment.

A quick summary of what this script does:

- Attempts to automatically detect windows internal database vs sql server
- Creates indexes to speed up the WSUS database
- Defragments existing database indexes
- Declines a lot of updates - **customize this for your environment**
- Clears the WSUS sync history
- Changes the WSUS IIS app pool to crash less
- Cleans up IIS logs > 30 days
- Runs the SCCM content library cleanup tool for your DP if it's present in the folder
