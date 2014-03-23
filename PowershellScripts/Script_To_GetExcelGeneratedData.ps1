$contents = get-clipboard
$c = split-string -input $contents -newline -removeemptystrings
$c | out-clipboard
