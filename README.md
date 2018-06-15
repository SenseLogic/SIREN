![](https://github.com/senselogic/SIREN/blob/master/LOGO/siren.png)

# Siren

Scriptable file renamer.

## Sample

```bash
IncludeFiles *

IgnoreFiles rename.*
EditName

SetCamelCase
ReplaceText " " _
ReplaceCharacters "<>:'\"\\|?*=&" -

SelectFiles *.pdf
AppendFiles *.png
AppendFiles *.jpg
AppendFiles *.txt
IgnoreMatchingFiles ^\d\d\d\d_\d\d_\d\d_.*$
EditName

InsertTime <year>_<month:2>_<day:2>_ 0

ConfirmChanges
ApplyChanges
```

## Limitations

* Symbolic links are not processed.

## Installation

Install the [DMD 2.076 compiler](https://dlang.org/download.html).

Build the executable with the following command line :

```bash
dmd -m64 siren.d
```

## Command line

```bash
siren [options]
```

### Options

```
--create : create the new folders if they don't exist
--verbose : show the execution messages
--preview : preview the changes without applying them
--include_files file_path_filter
--exclude_files file_path_filter
--select_files file_path_filter
--append_files file_path_filter
--ignore_files file_path_filter
--select_matching_files file_path_expression
--append_matching_files file_path_expression
--ignore_matching_files file_path_expression
--select_found_files
--ignore_found_files
--edit_range first_position post_position
--edit_folder
--edit_folder_name
--edit_folder_name_extension
--edit_name
--edit_name_extension
--edit_extension
--find_range first_position post_position
--find_text format
--find_last_text format
--find_prefix format
--find_suffix format
--find_expression expression
--replace_text old_text new_format
--replace_prefix old_prefix new_format
--replace_suffix old_suffix new_format
--replace_range first_position post_position new_format
--replace_characters old_characters new_format
--replace_expression old_expression new text
--replace_expression_once_old expression new text
--set_lower_case
--set_upper_case
--set_minor_case
--set_major_case
--set_camel_case
--set_snake_case
--set_text new text
--remove
--remove_range first_position post_position
--insert_text format position
--insert_prefix format
--insert_suffix format
--print text
--print_files format
--print_selected_files format
--print_changed_selected_files format
--print_changed_files format
--print_changes
--confirm_changes
--apply_changes
--exit
--run script_file_path
```

### Commands

```bash
IncludeFiles file_path_filter
ExcludeFiles file_path_filter
SelectFiles file_path_filter
AppendFiles file_path_filter
IgnoreFiles file_path_filter
SelectMatchingFiles file_path_expression
AppendMatchingFiles file_path_expression
IgnoreMatchingFiles file_path_expression
SelectFoundFiles
IgnoreFoundFiles
EditRange first_position post_position
EditFolder
EditFolderName
EditFolderNameExtension
EditName
EditNameExtension
EditExtension
FindRange first_position post_position
FindText format
FindLastText format
FindPrefix format
FindSuffix format
FindExpression expression
ReplaceText old_text new_format
ReplacePrefix old_prefix new_format
ReplaceSuffix old_suffix new_format
ReplaceRange first_position post_position new_format
ReplaceCharacters old characters new_format
ReplaceExpression old expression new text
ReplaceExpressionOnce old expression new text
SetLowerCase
SetUpperCase
SetMinorCase
SetMajorCase
SetCamelCase
SetSnakeCase
SetEditedText format
SetFoundText format
Remove
RemoveRange first_position post_position
InsertText format position
InsertPrefix format
InsertSuffix format
Print text
PrintFiles format
PrintSelectedFiles format
PrintChangedSelectedFiles format
PrintChangedFiles format
PrintChanges
ConfirmChanges
ApplyChanges
Exit
```

### File path filter

```
file_name_filter : select the matching files
FOLDER_PATH_FILTER/ : select all files in the matching folders
FOLDER_PATH_FILTER// : select all files in the matching folders and their subfolders
FOLDER_PATH_FILTER/file_name_filter : select the matching files in the matching folders
FOLDER_PATH_FILTER//file_name_filter : select the matching files in the matching folders and their subfolders
```

### Position

```
0, 1, 2, ... : from the start of the edited text
+0, +1, +2, ... : from the start of the edited text
-2, -1, -0, ... : from the end of the edited text
[-1, [0, [1, ... : from the start of the found text
]-1, ]0, ]1, ... : from the end of the found text
```

### Format

```
<edited_text> : edited text
<found_text> : found text
<old_folder> : old folder
<old_name> : old name
<old_extension> : old extension
<folder> : folder
<name> : name
<extension> : extension
<year> : year number
<year:2> : year number in two digits
<month> : month number
<month:2> : month number in two digits
<day> : day number
<day:2> : day number in two digits
<hour> : hour number
<hour:2> : hour number in two digits
<minute> : minute number
<minute:2> : minute number in two digits
<second> : second number
<second:2> : second number in two digits
<current_year> : current year number
<current_year:2> : current year number in two digits
<current_month> : current month number
<current_month:2> : current month number in two digits
<current_day> : current day number
<current_day:2> : current day number in two digits
<current_hour> : current hour number
<current_hour:2> : current hour number in two digits
<current_minute> : current minute number
<current_minute:2> : current minute number in two digits
<current_second> : current second number
<current_second:2> : current second number in two digits
\\ : escape next character
```

### Comment

```
-- this is a comment
```

### Examples

```bash
siren --preview -run script_file.siren
```

Execute the commands in the script file, previewing the changes without applying them.

```bash
siren --create -run script_file.siren
```

Execute the commands in the script file, creating the new folders if they don't exist.

```bash
siren --include_files "*.txt" --edit_name --set_snake_case --set_lower_case --apply_changes
```

Change all ".txt" file_names in the current folder to snake-case and lower-case.

## Version

1.0

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.




