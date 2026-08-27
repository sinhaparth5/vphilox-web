# IEEEtran two-column floats: pandoc's latex reader drops \caption and \label
# inside table*/figure*, but keeps both for the single-column environments.
s/\\begin{table\*}/\\begin{table}/g
s/\\end{table\*}/\\end{table}/g
s/\\begin{figure\*}/\\begin{figure}/g
s/\\end{figure\*}/\\end{figure}/g
# \IEEEPARstart{C}{onsider} is a drop-cap macro; pandoc drops both arguments.
s/\\IEEEPARstart{\([A-Z]\)}{\([a-z]*\)}/\1\2/g
