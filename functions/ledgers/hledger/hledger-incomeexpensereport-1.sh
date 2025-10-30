#!/bin/bash

# Define variables
REPORT_DATE=$(date +"%Y-%m-%d")
OUTPUT_DIR="./reports"
HLEDGER_FILE="$HOME/docs/acc/mg/desk/2025/mainledge-25-a.journal"  # Your hledger journal file path

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Create a markdown file with hledger data
cat > $OUTPUT_DIR/report_$REPORT_DATE.md << EOF
# Financial Report - $REPORT_DATE

## Income Statement

\`\`\`
$(hledger -f $HLEDGER_FILE incomestatement -p "this year")
\`\`\`

## Balance Sheet

\`\`\`
$(hledger -f $HLEDGER_FILE balancesheet)
\`\`\`

## Monthly Expenses

\`\`\`
$(hledger -f $HLEDGER_FILE balance expenses -M --pretty-tables)
\`\`\`

## Top 10 Expense Categories

\`\`\`
$(hledger -f $HLEDGER_FILE balance expenses -S -T -10)
\`\`\`
EOF

# Convert markdown to PDF using pandoc
pandoc $OUTPUT_DIR/report_$REPORT_DATE.md \
  -o $OUTPUT_DIR/report_$REPORT_DATE.pdf \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -V fontsize=12pt \
  -V colorlinks=true \
  --toc

echo "Report generated at $OUTPUT_DIR/report_$REPORT_DATE.pdf"
