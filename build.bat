pandoc -o "aws-redshift-fundamentals.epub" --columns 10000 --number-sections --toc --css epub.css meta.yaml  01.introduction.md 02.storage.md 03.distribution.md 04.importing.md 05.table-maintenance.md 06.exporting.md 07.query-processing.md 08.wlm.md 99.credits.md 
pandoc -o "aws-redshift-fundamentals.html" --include-in-header html-css.include --number-sections --toc meta.yaml  01.introduction.md 02.storage.md 03.distribution.md 04.importing.md 05.table-maintenance.md 06.exporting.md 07.query-processing.md 08.wlm.md 99.credits.md


 