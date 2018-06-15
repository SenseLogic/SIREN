#!/bin/sh
../siren --verbose --preview --run test.siren
../siren --create --verbose --preview --run test_2.siren
../siren --verbose --preview --include_files "*.txt" --edit_name --set_snake_case --set_lower_case --replace_text camel snake --print_changes
