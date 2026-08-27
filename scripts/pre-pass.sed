# IEEEtran two-column floats: pandoc's latex reader drops \caption and \label
# inside table*/figure*, but keeps both for the single-column environments.
s/\\begin{table\*}/\\begin{table}/g
s/\\end{table\*}/\\end{table}/g
s/\\begin{figure\*}/\\begin{figure}/g
s/\\end{figure\*}/\\end{figure}/g
# \IEEEPARstart{C}{onsider} is a drop-cap macro; pandoc drops both arguments.
s/\\IEEEPARstart{\([A-Z]\)}{\([a-z]*\)}/\1\2/g
# The abstract and the keywords live inside \IEEEtitleabstractindextext{...},
# which pandoc does not know, so it discards the whole argument -- the landing
# page came out with no abstract at all. Unwrap it: the brace opens on the macro
# line and closes on the \end{IEEEkeywords} line.
s/\\IEEEtitleabstractindextext{%*//
s/\\end{IEEEkeywords}}/\\end{IEEEkeywords}/
