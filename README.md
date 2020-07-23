# EOL Manager
For those who have to deal with text files from different platforms, you may have run into the three competing types of newlines: those used in DOS/Windows, in \*nix/macOS, and in the classic Mac OS. EOL Manager was written in order to survey the newline or end-of-line (EOL) types of a group of files, and then selectively change those EOL types. This script requires 'dos2unix' to run.

The full documentation for the script can be seen by running it without any arguments. The script can be used on a single file, but here's the mass operations you can do with EOL Manager:
- Print the EOL type for each file in a folder.
- Print the file names which only have a certain EOL type.
- Summarize the EOL types found for each of a set of file suffixes.
- Batch-change all files of one EOL type to another.
- Only change the files with certain suffixes from one EOL type to another.

![Preview](https://github.com/Iritscen/eol-manager/blob/master/preview.png)