/*
    This file is part of the Siren distribution.

    https://github.com/senselogic/SIREN

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    Siren is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Siren is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Siren. If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import std.algorithm : sort;
import std.ascii : toUpper;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.file : dirEntries, exists, getTimes, mkdirRecurse, readText, rename, FileException, SpanMode;
import std.path : globMatch;
import std.regex : regex, matchFirst, replaceAll, replaceFirst, Captures, Regex;
import std.stdio : readln, writeln;
import std.string : endsWith, indexOf, lastIndexOf, replace, split, startsWith, strip, toLower, toUpper;

// -- TYPES

struct SEGMENTED_FILE_PATH
{
    // -- ATTRIBUTES

    string
        FilePath;
    long
        FolderCharacterCount,
        NameCharacterCount,
        ExtensionCharacterCount;

    // -- INQUIRIES

    string GetFolder(
        )
    {
        return FilePath[ 0 .. FolderCharacterCount ];
    }

    // ~~

    string GetFolderFilter(
        )
    {
        string
            folder_filter;

        folder_filter = FilePath[ 0 .. FolderCharacterCount ];

        if ( folder_filter.endsWith( "//" ) )
        {
            folder_filter = folder_filter[ 0 .. $ -1 ] ~ '*';
        }

        return folder_filter;
    }

    // ~~

    string GetNameExtension(
        )
    {
        return FilePath[ FolderCharacterCount .. $ ];
    }

    // ~~

    string GetName(
        )
    {
        return FilePath[ FolderCharacterCount .. FolderCharacterCount + NameCharacterCount ];
    }

    // ~~

    string GetExtension(
        )
    {
        return FilePath[ FolderCharacterCount + NameCharacterCount .. $ ];
    }

    // -- OPERATIONS

    void SetFilePath(
        string file_path
        )
    {
        char
            character;
        long
            character_index,
            dot_character_index,
            slash_character_index;

        FilePath = file_path;

        slash_character_index = -1;
        dot_character_index = -1;

        for ( character_index = 0;
              character_index < file_path.length;
              ++character_index )
        {
            character = file_path[ character_index ];

            if ( character == '/' )
            {
                slash_character_index = character_index;
                dot_character_index = -1;
            }
            else if ( file_path[ character_index ] == '.' )
            {
                dot_character_index = character_index;
            }
        }

        if ( slash_character_index >= 0 )
        {
            FolderCharacterCount = slash_character_index + 1;
        }
        else
        {
            FolderCharacterCount = 0;
        }

        if ( dot_character_index >= 0 )
        {
            NameCharacterCount = dot_character_index - FolderCharacterCount;
            ExtensionCharacterCount = file_path.length.to!long() - dot_character_index;
        }
        else
        {
            NameCharacterCount = file_path.length.to!long() - FolderCharacterCount;
            ExtensionCharacterCount = 0;
        }
    }
}

// ~~

enum ORIGIN
{
    // -- CONSTANTS

    FirstCharacter,
    PostCharacter,
    FirstSelectedCharacter,
    PostSelectedCharacter
}

// ~~

struct POSITION
{
    // -- ATTRIBUTES

    ORIGIN
        Origin;
    long
        Offset;

    // -- CONSTRUCTORS

    this(
        string text
        )
    {
        SetFromText( text );
    }

    // -- OPERATIONS

    void SetFromText(
        string text
        )
    {
        if ( text.startsWith( '[' ) )
        {
            Origin = ORIGIN.FirstSelectedCharacter;
            Offset = text[ 1 .. $ ].to!long();
        }
        else if ( text.startsWith( ']' ) )
        {
            Origin = ORIGIN.PostSelectedCharacter;
            Offset = text[ 1 .. $ ].to!long();
        }
        else if ( text.startsWith( '+' ) )
        {
            Origin = ORIGIN.FirstCharacter;
            Offset = text[ 1 .. $ ].to!long();
        }
        else if ( text.startsWith( '-' ) )
        {
            Origin = ORIGIN.PostCharacter;
            Offset = -text[ 1 .. $ ].to!long();
        }
        else
        {
            Origin = ORIGIN.FirstCharacter;
            Offset = text.to!long();
        }
    }
}

// ~~

struct RANGE
{
    // -- ATTRIBUTES

    POSITION
        FirstPosition,
        PostPosition;
}

// ~~

struct CHARACTER_RANGE
{
    // -- ATTRIBUTES

    long
        FirstCharacterIndex,
        PostCharacterIndex;

    // -- CONSTRUCTORS

    this(
        long first_character_index,
        long post_character_index
        )
    {
        FirstCharacterIndex = first_character_index;
        PostCharacterIndex = post_character_index;
    }

    // -- INQUIRIES

    long GetCharacterCount(
        )
    {
        return PostCharacterIndex - FirstCharacterIndex;
    }

    // ~~

    string GetString(
        string text
        )
    {
        return text[ FirstCharacterIndex .. PostCharacterIndex ];
    }

    // -- OPERATIONS

    void InsertCharacters(
        long character_index,
        long character_count
        )
    {
        if ( character_count > 0 )
        {
            if ( character_index < FirstCharacterIndex )
            {
                FirstCharacterIndex += character_count;
            }

            if ( character_index <= PostCharacterIndex )
            {
                PostCharacterIndex += character_count;
            }
        }
    }

    // ~~

    void RemoveCharacters(
        long character_index,
        long character_count
        )
    {
        if ( character_count > 0 )
        {
            if ( character_index < FirstCharacterIndex )
            {
                FirstCharacterIndex -= character_count;
            }

            if ( character_index <= PostCharacterIndex )
            {
                PostCharacterIndex -= character_count;
            }

            if ( FirstCharacterIndex < 0 )
            {
                FirstCharacterIndex = 0;
            }

            if ( PostCharacterIndex < FirstCharacterIndex )
            {
                PostCharacterIndex = FirstCharacterIndex;
            }
        }
    }
}

// ~~

class FILE
{
    // -- ATTRIBUTES

    string
        OldPath,
        NewPath;
    SysTime
        Time;
    bool
        IsSelected,
        IsFound;
    CHARACTER_RANGE
        EditedCharacterRange,
        FoundCharacterRange;

    // -- CONSTRUCTORS

    this(
        string path,
        SysTime time
        )
    {
        SetPath( path );

        Time = time;
        IsSelected = true;
    }

    // -- INQUIRIES

    long GetCharacterIndex(
        POSITION position
        )
    {
        long
            character_index;

        if ( position.Origin == ORIGIN.FirstCharacter )
        {
            character_index = EditedCharacterRange.FirstCharacterIndex + position.Offset;
        }
        else if ( position.Origin == ORIGIN.PostCharacter )
        {
            character_index = EditedCharacterRange.PostCharacterIndex + position.Offset;
        }
        else if ( position.Origin == ORIGIN.FirstSelectedCharacter )
        {
            if ( IsFound )
            {
                character_index = FoundCharacterRange.FirstCharacterIndex + position.Offset;
            }
            else
            {
                character_index = EditedCharacterRange.PostCharacterIndex + position.Offset;
            }
        }
        else if ( position.Origin == ORIGIN.PostSelectedCharacter )
        {
            if ( IsFound )
            {
                character_index = FoundCharacterRange.PostCharacterIndex + position.Offset;
            }
            else
            {
                character_index = EditedCharacterRange.PostCharacterIndex + position.Offset;
            }
        }

        if ( character_index < 0 )
        {
            character_index = 0;
        }
        else if ( character_index > NewPath.length )
        {
            character_index = NewPath.length;
        }

        return character_index;
    }

    // ~~

    long GetCharacterIndex(
        string position
        )
    {
        return GetCharacterIndex( POSITION( position ) );
    }

    // ~~

    CHARACTER_RANGE GetCharacterRange(
        RANGE range
        )
    {
        return
            CHARACTER_RANGE(
                GetCharacterIndex( range.FirstPosition ),
                GetCharacterIndex( range.PostPosition )
                );
    }

    // ~~

    string GetEditedText(
        )
    {
        return NewPath[ EditedCharacterRange.FirstCharacterIndex .. EditedCharacterRange.PostCharacterIndex ];
    }

    // ~~

    string GetFoundText(
        )
    {
        if ( IsFound )
        {
            return NewPath[ FoundCharacterRange.FirstCharacterIndex .. FoundCharacterRange.PostCharacterIndex ];
        }
        else
        {
            return "";
        }
    }

    // ~~

    string GetFormattedText(
        string format
        )
    {
        bool
            character_is_processed;
        char
            character;
        long
            character_index,
            first_character_index;
        string
            command,
            text;
        SysTime
            time;
        SEGMENTED_FILE_PATH
            new_segmented_file_path,
            old_segmented_file_path;

        old_segmented_file_path.SetFilePath( OldPath );
        new_segmented_file_path.SetFilePath( NewPath );

        time = Clock.currTime();

        for ( character_index = 0;
              character_index < format.length;
              ++character_index )
        {
            character = format[ character_index ];
            character_is_processed = false;

            if ( character == '\\'
                 && character_index + 1 < format.length
                 && format[ character_index + 1 ] == '<' )
            {
                character_is_processed = true;

                ++character_index;

                text ~= '<';
            }
            else if ( character == '<' )
            {
                for ( first_character_index = character_index;
                      character_index < format.length;
                      ++character_index )
                {
                    if ( format[ character_index ] == '>' )
                    {
                        character_is_processed = true;

                        command = format[ first_character_index .. character_index + 1 ];

                        if ( command == "<edited_text>" )
                        {
                            text ~= GetEditedText();
                        }
                        else if ( command == "<found_text>" )
                        {
                            text ~= GetFoundText();
                        }
                        else if ( command == "<old_folder>" )
                        {
                            text ~= old_segmented_file_path.GetFolder();
                        }
                        else if ( command == "<old_name>" )
                        {
                            text ~= old_segmented_file_path.GetName();
                        }
                        else if ( command == "<old_extension>" )
                        {
                            text ~= old_segmented_file_path.GetExtension();
                        }
                        else if ( command == "<folder>" )
                        {
                            text ~= new_segmented_file_path.GetFolder();
                        }
                        else if ( command == "<name>" )
                        {
                            text ~= new_segmented_file_path.GetName();
                        }
                        else if ( command == "<extension>" )
                        {
                            text ~= new_segmented_file_path.GetExtension();
                        }
                        else if ( command == "<year>" )
                        {
                            text ~= Time.year().to!string();
                        }
                        else if ( command == "<year:2>" )
                        {
                            text ~= Time.year().to!string()[ $ - 2 .. $ ];
                        }
                        else if ( command == "<month>" )
                        {
                            text ~= Time.month().to!int().to!string();
                        }
                        else if ( command == "<month:2>" )
                        {
                            text ~= ( "00" ~ Time.month().to!int().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<day>" )
                        {
                            text ~= Time.day().to!string();
                        }
                        else if ( command == "<day:2>" )
                        {
                            text ~= ( "00" ~ Time.day().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<hour>" )
                        {
                            text ~= Time.hour().to!int().to!string();
                        }
                        else if ( command == "<hour:2>" )
                        {
                            text ~= ( "00" ~ Time.hour().to!int().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<minute>" )
                        {
                            text ~= Time.minute().to!string();
                        }
                        else if ( command == "<minute:2>" )
                        {
                            text ~= ( "00" ~ Time.minute().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<second>" )
                        {
                            text ~= Time.second().to!string();
                        }
                        else if ( command == "<second:2>" )
                        {
                            text ~= ( "00" ~ Time.second().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_year>" )
                        {
                            text ~= time.year().to!string();
                        }
                        else if ( command == "<current_year:2>" )
                        {
                            text ~= time.year().to!string()[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_month>" )
                        {
                            text ~= time.month().to!int().to!string();
                        }
                        else if ( command == "<current_month:2>" )
                        {
                            text ~= ( "00" ~ time.month().to!int().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_day>" )
                        {
                            text ~= time.day().to!string();
                        }
                        else if ( command == "<current_day:2>" )
                        {
                            text ~= ( "00" ~ time.day().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_hour>" )
                        {
                            text ~= time.hour().to!int().to!string();
                        }
                        else if ( command == "<current_hour:2>" )
                        {
                            text ~= ( "00" ~ time.hour().to!int().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_minute>" )
                        {
                            text ~= time.minute().to!string();
                        }
                        else if ( command == "<current_minute:2>" )
                        {
                            text ~= ( "00" ~ time.minute().to!string() )[ $ - 2 .. $ ];
                        }
                        else if ( command == "<current_second>" )
                        {
                            text ~= time.second().to!string();
                        }
                        else if ( command == "<current_second:2>" )
                        {
                            text ~= ( "00" ~ time.second().to!string() )[ $ - 2 .. $ ];
                        }
                        else
                        {
                            character_is_processed = false;
                        }

                        break;
                    }
                }

                if ( !character_is_processed )
                {
                    character_index = first_character_index;
                }
            }

            if ( !character_is_processed )
            {
                text ~= character;
            }
        }

        return text;
    }

    // ~~

    void Print(
        string format
        )
    {
        if ( format == "" )
        {
            if ( IsSelected )
            {
                writeln( "<< ", OldPath );

                if ( NewPath != OldPath )
                {
                    writeln( ">> ", NewPath );
                }
            }
            else
            {
                writeln( "[[ ", OldPath );

                if ( NewPath != OldPath )
                {
                    writeln( "]] ", NewPath );
                }
            }

            if ( EditedCharacterRange.FirstCharacterIndex != 0
                 || EditedCharacterRange.PostCharacterIndex != NewPath.length )
            {
                writeln( " % ", EditedCharacterRange.GetString( NewPath ) );
            }

            if ( IsFound )
            {
                writeln( " ? ", FoundCharacterRange.GetString( NewPath ) );
            }
        }
        else
        {
            writeln( GetFormattedText( format ) );
        }
    }

    // -- OPERATIONS

    void SetPath(
        const string path
        )
    {
        OldPath = path;
        NewPath = path;
        IsFound = false;
        EditedCharacterRange.FirstCharacterIndex = 0;
        EditedCharacterRange.PostCharacterIndex = path.length;
    }


    // ~~

    void ReplaceRange(
        long first_character_index,
        long post_character_index,
        string text
        )
    {
        long
            character_index,
            character_offset;

        NewPath = NewPath[ 0 .. first_character_index ] ~ text ~ NewPath[ post_character_index .. $ ];

        character_offset = text.length.to!long() - ( post_character_index - first_character_index );

        if ( character_offset > 0 )
        {
            character_index = post_character_index;

            EditedCharacterRange.InsertCharacters( character_index, character_offset );
            FoundCharacterRange.InsertCharacters( character_index, character_offset );
        }
        else if ( character_offset < 0 )
        {
            character_index = post_character_index + character_offset;

            EditedCharacterRange.RemoveCharacters( character_index, -character_offset );
            FoundCharacterRange.RemoveCharacters( character_index, -character_offset );
        }
    }

    // ~~

    void ReplaceRange(
        string first_position,
        string post_position,
        string text
        )
    {
        ReplaceRange( GetCharacterIndex( first_position ), GetCharacterIndex( post_position ), text );
    }

    // ~~

    void SetEditedText(
        string text
        )
    {
        ReplaceRange( EditedCharacterRange.FirstCharacterIndex, EditedCharacterRange.PostCharacterIndex, text );
    }

    // ~~

    void SetFoundText(
        string text
        )
    {
        if ( IsFound )
        {
            ReplaceRange( FoundCharacterRange.FirstCharacterIndex, FoundCharacterRange.PostCharacterIndex, text );
        }
    }

    // ~~

    void Remove(
        )
    {
        SetEditedText( "" );
    }

    // ~~

    void RemoveRange(
        string first_position,
        string post_position
        )
    {
        ReplaceRange( GetCharacterIndex( first_position ), GetCharacterIndex( post_position ), "" );
    }

    // ~~

    void InsertText(
        string text,
        long character_index
        )
    {
        NewPath = NewPath[ 0 .. character_index ] ~ text ~ NewPath[ character_index .. $ ];

        EditedCharacterRange.InsertCharacters( character_index, text.length );
        FoundCharacterRange.InsertCharacters( character_index, text.length );
    }

    // ~~

    void InsertText(
        string text,
        string position
        )
    {
        InsertText( text, GetCharacterIndex( position ) );
    }

    // ~~

    void InsertPrefix(
        string text
        )
    {
        InsertText( text, EditedCharacterRange.FirstCharacterIndex );
    }

    // ~~

    void InsertSuffix(
        string text
        )
    {
        InsertText( text, EditedCharacterRange.PostCharacterIndex );
    }
}

// ~~

class SCRIPT
{
    // -- ATTRIBUTES

    FILE[ string ]
        FileMap;
    bool
        ChangesAreApplied;

    // -- CONSTRUCTORS

    this(
        )
    {
        ChangesAreApplied = true;
    }

    // -- OPERATIONS

    void IncludeFiles(
        string file_path_filter
        )
    {
        bool
            it_is_recursive;
        string
            file_name_filter,
            file_path,
            folder_path;
        SysTime
            file_access_time,
            file_modification_time;
        SEGMENTED_FILE_PATH
            segmented_file_path_filter;

        segmented_file_path_filter.SetFilePath( file_path_filter );

        folder_path = segmented_file_path_filter.GetFolder();

        it_is_recursive = folder_path.endsWith( "//" );

        if ( it_is_recursive )
        {
            folder_path = folder_path[ 0 .. $ - 1 ];
        }

        foreach (
            folder_entry;
            dirEntries( folder_path, it_is_recursive ? SpanMode.depth : SpanMode.shallow )
            )
        {
            if ( folder_entry.isFile()
                 && !folder_entry.isSymlink() )
            {
                file_path = folder_entry;

                if ( file_path.MatchesFilter( file_path_filter )
                     && ( file_path in FileMap ) is null )
                {
                    getTimes( file_path, file_access_time, file_modification_time );

                    FileMap[ file_path ] = new FILE( file_path, file_modification_time );
                }
            }
        }
    }

    // ~~

    void ExcludeFiles(
        string file_path_filter
        )
    {
        string[]
            removed_file_path_array;

        foreach ( file; FileMap )
        {
            if ( file.NewPath.MatchesFilter( file_path_filter ) )
            {
                removed_file_path_array ~= file.OldPath;
            }
        }

        foreach ( removed_file_path; removed_file_path_array )
        {
            FileMap.remove( removed_file_path );
        }
    }

    // ~~

    void SelectFiles(
        string file_path_filter
        )
    {
        foreach ( file; FileMap )
        {
            file.IsSelected = file.NewPath.MatchesFilter( file_path_filter );
        }
    }

    // ~~

    void AppendFiles(
        string file_path_filter
        )
    {
        foreach ( file; FileMap )
        {
            if ( !file.IsSelected
                 && file.NewPath.MatchesFilter( file_path_filter ) )
            {
                file.IsSelected = true;
            }
        }
    }

    // ~~

    void IgnoreFiles(
        string file_path_filter
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected
                 && file.NewPath.MatchesFilter( file_path_filter ) )
            {
                file.IsSelected = false;
            }
        }
    }

    // ~~

    void SelectMatchingFiles(
        string file_path_expression
        )
    {
        Regex!char
            regular_expression;

        regular_expression = regex( file_path_expression );

        foreach ( file; FileMap )
        {
            file.IsSelected = file.NewPath.MatchesExpression( regular_expression );
        }
    }

    // ~~

    void AppendMatchingFiles(
        string file_path_expression
        )
    {
        Regex!char
            regular_expression;

        regular_expression = regex( file_path_expression );

        foreach ( file; FileMap )
        {
            if ( !file.IsSelected
                 && file.NewPath.MatchesExpression( regular_expression ) )
            {
                file.IsSelected = true;
            }
        }
    }

    // ~~

    void IgnoreMatchingFiles(
        string file_path_expression
        )
    {
        Regex!char
            regular_expression;

        regular_expression = regex( file_path_expression );

        foreach ( file; FileMap )
        {
            if ( file.IsSelected
                 && file.NewPath.MatchesExpression( regular_expression ) )
            {
                file.IsSelected = false;
            }
        }
    }

    // ~~

    void SelectFoundFiles(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected
                 && !file.IsFound )
            {
                file.IsSelected = false;
            }
        }
    }

    // ~~

    void IgnoreFoundFiles(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected
                 && file.IsFound )
            {
                file.IsSelected = false;
            }
        }
    }

    // ~~

    void EditRange(
        string first_position,
        string post_position
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.EditedCharacterRange.FirstCharacterIndex = file.GetCharacterIndex( first_position );
                file.EditedCharacterRange.PostCharacterIndex = file.GetCharacterIndex( post_position );
            }
        }
    }

    // ~~

    void EditFolder(
        )
    {
        SEGMENTED_FILE_PATH
            segmented_file_path;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                segmented_file_path.SetFilePath( file.NewPath );

                file.EditedCharacterRange.FirstCharacterIndex = 0;
                file.EditedCharacterRange.PostCharacterIndex = segmented_file_path.FolderCharacterCount;
            }
        }
    }

    // ~~

    void EditFolderName(
        )
    {
        SEGMENTED_FILE_PATH
            segmented_file_path;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                segmented_file_path.SetFilePath( file.NewPath );

                file.EditedCharacterRange.FirstCharacterIndex = 0;
                file.EditedCharacterRange.PostCharacterIndex = file.NewPath.length.to!long() - segmented_file_path.ExtensionCharacterCount;
            }
        }
    }

    // ~~

    void EditFolderNameExtension(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.EditedCharacterRange.FirstCharacterIndex = 0;
                file.EditedCharacterRange.PostCharacterIndex = file.NewPath.length;
            }
        }
    }

    // ~~

    void EditName(
        )
    {
        SEGMENTED_FILE_PATH
            segmented_file_path;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                segmented_file_path.SetFilePath( file.NewPath );

                file.EditedCharacterRange.FirstCharacterIndex = segmented_file_path.FolderCharacterCount;
                file.EditedCharacterRange.PostCharacterIndex = file.NewPath.length.to!long() - segmented_file_path.ExtensionCharacterCount;
            }
        }
    }

    // ~~

    void EditNameExtension(
        )
    {
        SEGMENTED_FILE_PATH
            segmented_file_path;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                segmented_file_path.SetFilePath( file.NewPath );

                file.EditedCharacterRange.FirstCharacterIndex = segmented_file_path.FolderCharacterCount;
                file.EditedCharacterRange.PostCharacterIndex = file.NewPath.length;
            }
        }
    }

    // ~~

    void EditExtension(
        )
    {
        SEGMENTED_FILE_PATH
            segmented_file_path;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                segmented_file_path.SetFilePath( file.NewPath );

                file.EditedCharacterRange.FirstCharacterIndex = file.NewPath.length.to!long() - segmented_file_path.ExtensionCharacterCount;
                file.EditedCharacterRange.PostCharacterIndex = file.NewPath.length;
            }
        }
    }

    // ~~

    void FindRange(
        string first_position,
        string post_position
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.IsFound = true;

                file.FoundCharacterRange.FirstCharacterIndex = file.GetCharacterIndex( first_position );
                file.FoundCharacterRange.PostCharacterIndex = file.GetCharacterIndex( post_position );
            }
        }
    }

    // ~~

    void FindText(
        string format
        )
    {
        long
            character_index;
        string
            text;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                text = file.GetFormattedText( format );
                character_index = file.GetEditedText().indexOf( text );

                if ( character_index >= 0 )
                {
                    file.IsFound = true;

                    file.FoundCharacterRange.FirstCharacterIndex = file.EditedCharacterRange.FirstCharacterIndex + character_index;
                    file.FoundCharacterRange.PostCharacterIndex = file.FoundCharacterRange.FirstCharacterIndex + text.length;
                }
                else
                {
                    file.IsFound = false;
                }
            }
        }
    }

    // ~~

    void FindLastText(
        string format
        )
    {
        long
            character_index;
        string
            text;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                text = file.GetFormattedText( format );
                character_index = file.GetEditedText().lastIndexOf( text );

                if ( character_index >= 0 )
                {
                    file.IsFound = true;

                    file.FoundCharacterRange.FirstCharacterIndex = file.EditedCharacterRange.FirstCharacterIndex + character_index;
                    file.FoundCharacterRange.PostCharacterIndex = file.FoundCharacterRange.FirstCharacterIndex + text.length;
                }
                else
                {
                    file.IsFound = false;
                }
            }
        }
    }

    // ~~

    void FindPrefix(
        string format
        )
    {
        string
            text;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                text = file.GetFormattedText( format );

                if ( file.GetEditedText().startsWith( text ) )
                {
                    file.IsFound = true;

                    file.FoundCharacterRange.FirstCharacterIndex = file.EditedCharacterRange.FirstCharacterIndex;
                    file.FoundCharacterRange.PostCharacterIndex = file.FoundCharacterRange.FirstCharacterIndex + text.length;
                }
                else
                {
                    file.IsFound = false;
                }
            }
        }
    }

    // ~~

    void FindSuffix(
        string format
        )
    {
        string
            text;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                text = file.GetFormattedText( format );

                if ( file.GetEditedText().endsWith( text ) )
                {
                    file.IsFound = true;

                    file.FoundCharacterRange.FirstCharacterIndex = file.EditedCharacterRange.PostCharacterIndex - text.length.to!long();
                    file.FoundCharacterRange.PostCharacterIndex = file.EditedCharacterRange.PostCharacterIndex;
                }
                else
                {
                    file.IsFound = false;
                }
            }
        }
    }

    // ~~

    void FindExpression(
        string expression
        )
    {
        long
            character_index;
        Captures!( string )
            match;
        Regex!char
            regular_expression;

        regular_expression = regex( expression );

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                match = file.GetEditedText().matchFirst( regular_expression );

                if ( !match.empty() )
                {
                    character_index = match.pre.length;

                    file.IsFound = true;

                    file.FoundCharacterRange.FirstCharacterIndex = file.EditedCharacterRange.FirstCharacterIndex + character_index;
                    file.FoundCharacterRange.PostCharacterIndex = file.FoundCharacterRange.FirstCharacterIndex + match[ 0 ].length;
                }
                else
                {
                    file.IsFound = false;
                }
            }
        }
    }

    // ~~

    void ReplaceText(
        string old_format,
        string new_format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText(
                    file.GetEditedText().replace( file.GetFormattedText( old_format ), file.GetFormattedText( new_format ) )
                    );
            }
        }
    }

    // ~~

    void ReplacePrefix(
        string old_format,
        string new_format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText(
                    file.GetEditedText().ReplacePrefix( file.GetFormattedText( old_format ), file.GetFormattedText( new_format ) )
                    );
            }
        }
    }

    // ~~

    void ReplaceSuffix(
        string old_format,
        string new_format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText(
                    file.GetEditedText().ReplaceSuffix( file.GetFormattedText( old_format ), file.GetFormattedText( new_format ) )
                    );
            }
        }
    }

    // ~~

    void ReplaceRange(
        string first_position,
        string post_position,
        string new_format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.ReplaceRange( first_position, post_position, file.GetFormattedText( new_format ) );
            }
        }
    }

    // ~~

    void ReplaceCharacters(
        string old_characters,
        string new_format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().ReplaceCharacters( old_characters, file.GetFormattedText( new_format ) ) );
            }
        }
    }

    // ~~

    void ReplaceExpression(
        string old_expression,
        string new_expression
        )
    {
        Regex!char
            regular_expression;

        regular_expression = regex( old_expression );

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().replaceAll( regular_expression, new_expression ) );
            }
        }
    }

    // ~~

    void ReplaceExpressionOnce(
        string old_expression,
        string new_expression
        )
    {
        Regex!char
            regular_expression;

        regular_expression = regex( old_expression );

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().replaceFirst( regular_expression, new_expression ) );
            }
        }
    }

    // ~~

    void SetLowerCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetLowerCaseText() );
            }
        }
    }

    // ~~

    void SetUpperCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetUpperCaseText() );
            }
        }
    }

    // ~~

    void SetMinorCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetMinorCaseText() );
            }
        }
    }

    // ~~

    void SetMajorCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetMajorCaseText() );
            }
        }
    }

    // ~~

    void SetCamelCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetCamelCaseText() );
            }
        }
    }

    // ~~

    void SetSnakeCase(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetEditedText().GetSnakeCaseText() );
            }
        }
    }

    // ~~

    void SetEditedText(
        string format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetEditedText( file.GetFormattedText( format ) );
            }
        }
    }

    // ~~

    void SetFoundText(
        string format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.SetFoundText( file.GetFormattedText( format ) );
            }
        }
    }

    // ~~

    void Remove(
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.Remove();
            }
        }
    }

    // ~~

    void RemoveRange(
        string first_position,
        string post_position
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.RemoveRange( first_position, post_position );
            }
        }
    }

    // ~~

    void InsertText(
        string format,
        string position
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.InsertText( file.GetFormattedText( format ), position );
            }
        }
    }

    // ~~

    void InsertPrefix(
        string format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.InsertPrefix( file.GetFormattedText( format ) );
            }
        }
    }

    // ~~

    void InsertSuffix(
        string format
        )
    {
        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                file.InsertSuffix( file.GetFormattedText( format ) );
            }
        }
    }

    // ~~

    void Print(
        string text
        )
    {
        writeln( text );
    }

    // ~~

    void PrintFiles(
        string[] old_file_path_array,
        string format
        )
    {
        old_file_path_array.sort();

        foreach ( old_file_path; old_file_path_array )
        {
            FileMap[ old_file_path ].Print( format );
        }
    }

    // ~~

    void PrintFiles(
        string format
        )
    {
        string[]
            old_file_path_array;

        foreach ( file; FileMap )
        {
            old_file_path_array ~= file.OldPath;
        }

        PrintFiles( old_file_path_array, format );
    }

    // ~~

    void PrintSelectedFiles(
        string format
        )
    {
        string[]
            old_file_path_array;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected )
            {
                old_file_path_array ~= file.OldPath;
            }
        }

        PrintFiles( old_file_path_array, format );
    }

    // ~~

    void PrintChangedSelectedFiles(
        string format
        )
    {
        string[]
            old_file_path_array;

        foreach ( file; FileMap )
        {
            if ( file.IsSelected
                 && file.NewPath != file.OldPath )
            {
                old_file_path_array ~= file.OldPath;
            }
        }

        PrintFiles( old_file_path_array, format );
    }

    // ~~

    void PrintChangedFiles(
        string format
        )
    {
        string[]
            old_file_path_array;

        foreach ( file; FileMap )
        {
            if ( file.NewPath != file.OldPath )
            {
                old_file_path_array ~= file.OldPath;
            }
        }

        PrintFiles( old_file_path_array, format );
    }

    // ~~

    void PrintChanges(
        )
    {
        string[]
            old_file_path_array;
        FILE
            renamed_file;

        foreach ( file; FileMap )
        {
            if ( file.NewPath != file.OldPath )
            {
                old_file_path_array ~= file.OldPath;
            }
        }

        old_file_path_array.sort();

        foreach ( old_file_path; old_file_path_array )
        {
            renamed_file = FileMap[ old_file_path ];

            writeln( "<< ", renamed_file.OldPath );
            writeln( ">> ", renamed_file.NewPath );
        }
    }

    // ~~

    void ConfirmChanges(
        )
    {
        PrintChanges();

        ChangesAreApplied = AskConfirmation();
    }

    // ~~

    void ApplyChanges(
        )
    {
        string[]
            old_file_path_array;
        FILE
            renamed_file;
        FILE[]
            file_array;

        if ( ChangesAreApplied )
        {
            foreach ( file; FileMap )
            {
                if ( file.NewPath != file.OldPath )
                {
                    old_file_path_array ~= file.OldPath;

                    file_array ~= file;
                }
            }

            old_file_path_array.sort();

            foreach ( old_file_path; old_file_path_array )
            {
                renamed_file = FileMap[ old_file_path ];

                writeln( "<< ", renamed_file.OldPath );
                writeln( ">> ", renamed_file.NewPath );

                old_file_path.RenameFile( renamed_file.NewPath );

                FileMap.remove( old_file_path );
            }

            foreach ( file; file_array )
            {
                file.SetPath( file.NewPath );

                FileMap[ file.OldPath ] = file;
            }
        }
        else
        {
            ChangesAreApplied = true;
        }
    }

    // ~~

    string[] GetArgumentArray(
        string line
        )
    {
        bool
            it_is_in_string;
        char
            character;
        long
            character_index;
        string[]
            argument_array;

        it_is_in_string = false;

        argument_array ~= "";

        for ( character_index = 0;
              character_index < line.length;
              ++character_index )
        {
            character = line[ character_index ];

            if ( it_is_in_string )
            {
                if ( character == '\\'
                     && character_index + 1 < line.length
                     && line[ character_index + 1 ] == '\"' )
                {
                    ++character_index;

                    argument_array[ $ - 1 ] ~= '\"';
                }
                else if ( character == '\"' )
                {
                    it_is_in_string = false;
                }
                else
                {
                    argument_array[ $ - 1 ] ~= character;
                }
            }
            else if ( character == '\"' )
            {
                it_is_in_string = true;
            }
            else if ( character == ' ' )
            {
                argument_array ~= "";
            }
            else
            {
                argument_array[ $ - 1 ] ~= character;
            }
        }

        return argument_array;
    }

    // ~~

    void Exit(
        )
    {
        exit( 0 );
    }


    // ~~

    void Run(
        string script_file_path
        )
    {
        string
            command,
            script;
        string[]
            argument_array,
            line_array;

        script = script_file_path.readText().replace( "\r", "" ).replace( "\t", "    " );

        line_array = script.split( '\n' );

        foreach ( line; line_array )
        {
            line = line.strip();

            if ( line.length > 0
                 && !line.startsWith( '#' ) )
            {
                if ( VerboseOptionIsEnabled )
                {
                    writeln( line );
                }

                argument_array = GetArgumentArray( line );

                command = argument_array[ 0 ];
                argument_array = argument_array[ 1 .. $ ];

                if ( command == "IncludeFiles"
                     && argument_array.length == 1 )
                {
                    IncludeFiles( argument_array[ 0 ] );
                }
                else if ( command == "ExcludeFiles"
                          && argument_array.length == 1 )
                {
                    ExcludeFiles( argument_array[ 0 ] );
                }
                else if ( command == "SelectFiles"
                          && argument_array.length == 1 )
                {
                    SelectFiles( argument_array[ 0 ] );
                }
                else if ( command == "AppendFiles"
                          && argument_array.length == 1 )
                {
                    AppendFiles( argument_array[ 0 ] );
                }
                else if ( command == "IgnoreFiles"
                          && argument_array.length == 1 )
                {
                    IgnoreFiles( argument_array[ 0 ] );
                }
                else if ( command == "SelectMatchingFiles"
                          && argument_array.length == 1 )
                {
                    SelectMatchingFiles( argument_array[ 0 ] );
                }
                else if ( command == "AppendMatchingFiles"
                          && argument_array.length == 1 )
                {
                    AppendMatchingFiles( argument_array[ 0 ] );
                }
                else if ( command == "IgnoreMatchingFiles"
                          && argument_array.length == 1 )
                {
                    IgnoreMatchingFiles( argument_array[ 0 ] );
                }
                else if ( command == "SelectFoundFiles"
                          && argument_array.length == 0 )
                {
                    SelectFoundFiles();
                }
                else if ( command == "IgnoreFoundFiles"
                          && argument_array.length == 0 )
                {
                    IgnoreFoundFiles();
                }
                else if ( command == "EditRange"
                          && argument_array.length == 2 )
                {
                    EditRange( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "EditFolder"
                          && argument_array.length == 0 )
                {
                    EditFolder();
                }
                else if ( command == "EditFolderName"
                          && argument_array.length == 0 )
                {
                    EditFolderName();
                }
                else if ( command == "EditFolderNameExtension"
                          && argument_array.length == 0 )
                {
                    EditFolderNameExtension();
                }
                else if ( command == "EditName"
                          && argument_array.length == 0 )
                {
                    EditName();
                }
                else if ( command == "EditNameExtension"
                          && argument_array.length == 0 )
                {
                    EditNameExtension();
                }
                else if ( command == "EditExtension"
                          && argument_array.length == 0 )
                {
                    EditExtension();
                }
                else if ( command == "FindRange"
                          && argument_array.length == 2 )
                {
                    FindRange( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "FindText"
                          && argument_array.length == 1 )
                {
                    FindText( argument_array[ 0 ] );
                }
                else if ( command == "FindLastText"
                          && argument_array.length == 1 )
                {
                    FindLastText( argument_array[ 0 ] );
                }
                else if ( command == "FindPrefix"
                          && argument_array.length == 1 )
                {
                    FindPrefix( argument_array[ 0 ] );
                }
                else if ( command == "FindSuffix"
                          && argument_array.length == 1 )
                {
                    FindSuffix( argument_array[ 0 ] );
                }
                else if ( command == "FindExpression"
                          && argument_array.length == 1 )
                {
                    FindExpression( argument_array[ 0 ] );
                }
                else if ( command == "ReplaceText"
                          && argument_array.length == 2 )
                {
                    ReplaceText( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "ReplacePrefix"
                          && argument_array.length == 2 )
                {
                    ReplacePrefix( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "ReplaceSuffix"
                          && argument_array.length == 2 )
                {
                    ReplaceSuffix( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "ReplaceCharacters"
                          && argument_array.length == 2 )
                {
                    ReplaceCharacters( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "ReplaceRange"
                          && argument_array.length == 3 )
                {
                    ReplaceRange( argument_array[ 0 ], argument_array[ 1 ], argument_array[ 2 ] );
                }
                else if ( command == "ReplaceExpression"
                          && argument_array.length == 2 )
                {
                    ReplaceExpression( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "ReplaceExpressionOnce"
                          && argument_array.length == 2 )
                {
                    ReplaceExpressionOnce( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "SetLowerCase"
                          && argument_array.length == 0 )
                {
                    SetLowerCase();
                }
                else if ( command == "SetUpperCase"
                          && argument_array.length == 0 )
                {
                    SetUpperCase();
                }
                else if ( command == "SetMinorCase"
                          && argument_array.length == 0 )
                {
                    SetMinorCase();
                }
                else if ( command == "SetMajorCase"
                          && argument_array.length == 0 )
                {
                    SetMajorCase();
                }
                else if ( command == "SetCamelCase"
                          && argument_array.length == 0 )
                {
                    SetCamelCase();
                }
                else if ( command == "SetSnakeCase"
                          && argument_array.length == 0 )
                {
                    SetSnakeCase();
                }
                else if ( command == "SetEditedText"
                          && argument_array.length == 1 )
                {
                    SetEditedText( argument_array[ 0 ] );
                }
                else if ( command == "SetFoundText"
                          && argument_array.length == 1 )
                {
                    SetFoundText( argument_array[ 0 ] );
                }
                else if ( command == "Remove"
                          && argument_array.length == 0 )
                {
                    Remove();
                }
                else if ( command == "RemoveRange"
                          && argument_array.length == 2 )
                {
                    RemoveRange( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "InsertText"
                          && argument_array.length == 2 )
                {
                    InsertText( argument_array[ 0 ], argument_array[ 1 ] );
                }
                else if ( command == "InsertPrefix"
                          && argument_array.length == 1 )
                {
                    InsertPrefix( argument_array[ 0 ] );
                }
                else if ( command == "InsertSuffix"
                          && argument_array.length == 1 )
                {
                    InsertSuffix( argument_array[ 0 ] );
                }
                else if ( command == "Print"
                          && argument_array.length == 1 )
                {
                    Print( argument_array[ 0 ] );
                }
                else if ( command == "PrintFiles"
                          && argument_array.length == 1 )
                {
                    PrintFiles( argument_array[ 0 ] );
                }
                else if ( command == "PrintSelectedFiles"
                          && argument_array.length == 1 )
                {
                    PrintSelectedFiles( argument_array[ 0 ] );
                }
                else if ( command == "PrintChangedSelectedFiles"
                          && argument_array.length == 1 )
                {
                    PrintChangedSelectedFiles( argument_array[ 0 ] );
                }
                else if ( command == "PrintChangedFiles"
                          && argument_array.length == 1 )
                {
                    PrintChangedFiles( argument_array[ 0 ] );
                }
                else if ( command == "PrintChanges"
                          && argument_array.length == 0 )
                {
                    PrintChanges();
                }
                else if ( command == "ConfirmChanges"
                          && argument_array.length == 0 )
                {
                    ConfirmChanges();
                }
                else if ( command == "ApplyChanges"
                          && argument_array.length == 0 )
                {
                    ApplyChanges();
                }
                else if ( command == "Exit"
                          && argument_array.length == 0 )
                {
                    Exit();
                }
                else if ( command == "Run"
                          && argument_array.length == 1 )
                {
                    Run( argument_array[ 0 ] );
                }
                else
                {
                    Abort( "Invalid command : " ~ line );
                }
            }
        }
    }

    // ~~

    void ParseOption(
        ref string[] argument_array
        )
    {
        string
            option;

        while ( argument_array.length > 0 )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( argument_array[ 0 ] );
            }

            option = argument_array[ 0 ];
            argument_array = argument_array[ 1 .. $ ];

            if ( option == "--create" )
            {
                CreateOptionIsEnabled = true;
            }
            else if ( option == "--verbose" )
            {
                VerboseOptionIsEnabled = true;
            }
            else if ( option == "--preview" )
            {
                PreviewOptionIsEnabled = true;
            }
            else if ( option == "--include_files"
                      && argument_array.length >= 1 )
            {
                IncludeFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--exclude_files"
                      && argument_array.length >= 1 )
            {
                ExcludeFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--select_files"
                      && argument_array.length >= 1 )
            {
                SelectFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--append_files"
                      && argument_array.length >= 1 )
            {
                AppendFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--ignore_files"
                      && argument_array.length >= 1 )
            {
                IgnoreFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--select_matching_files"
                      && argument_array.length >= 1 )
            {
                SelectMatchingFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--append_matching_files"
                      && argument_array.length >= 1 )
            {
                AppendMatchingFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--ignore_matching_files"
                      && argument_array.length >= 1 )
            {
                IgnoreMatchingFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--select_found_files" )
            {
                SelectFoundFiles();
            }
            else if ( option == "--ignore_found_files" )
            {
                IgnoreFoundFiles();
            }
            else if ( option == "--edit_range"
                      && argument_array.length >= 2 )
            {
                EditRange( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--edit_folder" )
            {
                EditFolder();
            }
            else if ( option == "--edit_folder_name" )
            {
                EditFolderName();
            }
            else if ( option == "--edit_folder_name_extension" )
            {
                EditFolderNameExtension();
            }
            else if ( option == "--edit_name" )
            {
                EditName();
            }
            else if ( option == "--edit_name_extension" )
            {
                EditNameExtension();
            }
            else if ( option == "--edit_extension" )
            {
                EditExtension();
            }
            else if ( option == "--find_range"
                      && argument_array.length >= 2 )
            {
                FindRange( argument_array[ 0 ], argument_array[ 1 ] );
            }
            else if ( option == "--find_text"
                      && argument_array.length >= 1 )
            {
                FindText( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--find_last_text"
                      && argument_array.length >= 1 )
            {
                FindLastText( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--find_prefix"
                      && argument_array.length >= 1 )
            {
                FindPrefix( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--find_suffix"
                      && argument_array.length >= 1 )
            {
                FindSuffix( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--find_expression"
                      && argument_array.length >= 1 )
            {
                FindExpression( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--replace_text"
                      && argument_array.length >= 2 )
            {
                ReplaceText( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--replace_prefix"
                      && argument_array.length >= 2 )
            {
                ReplacePrefix( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--replace_suffix"
                      && argument_array.length >= 2 )
            {
                ReplaceSuffix( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--replace_range"
                      && argument_array.length >= 3 )
            {
                ReplaceRange( argument_array[ 0 ], argument_array[ 1 ], argument_array[ 2 ] );

                argument_array = argument_array[ 3 .. $ ];
            }
            else if ( option == "--replace_characters"
                      && argument_array.length >= 2 )
            {
                ReplaceCharacters( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--replace_expression"
                      && argument_array.length >= 2 )
            {
                ReplaceExpression( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--replace_expression_once"
                      && argument_array.length >= 2 )
            {
                ReplaceExpressionOnce( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--set_lower_case" )
            {
                SetLowerCase();
            }
            else if ( option == "--set_upper_case" )
            {
                SetUpperCase();
            }
            else if ( option == "--set_minor_case" )
            {
                SetMinorCase();
            }
            else if ( option == "--set_major_case" )
            {
                SetMajorCase();
            }
            else if ( option == "--set_camel_case" )
            {
                SetCamelCase();
            }
            else if ( option == "--set_snake_case" )
            {
                SetSnakeCase();
            }
            else if ( option == "--set_edited_text"
                      && argument_array.length >= 1 )
            {
                SetEditedText( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--set_found_text"
                      && argument_array.length >= 1 )
            {
                SetFoundText( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--remove" )
            {
                Remove();
            }
            else if ( option == "--remove_range"
                      && argument_array.length >= 2 )
            {
                RemoveRange( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--insert_text"
                      && argument_array.length >= 2 )
            {
                InsertText( argument_array[ 0 ], argument_array[ 1 ] );

                argument_array = argument_array[ 2 .. $ ];
            }
            else if ( option == "--insert_prefix"
                      && argument_array.length >= 1 )
            {
                InsertPrefix( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--insert_suffix"
                      && argument_array.length >= 1 )
            {
                InsertSuffix( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print"
                      && argument_array.length >= 1 )
            {
                Print( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print_files"
                      && argument_array.length >= 1 )
            {
                PrintFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print_selected_files"
                      && argument_array.length >= 1 )
            {
                PrintSelectedFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print_changed_selected_files"
                      && argument_array.length >= 1 )
            {
                PrintChangedSelectedFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print_changed_files"
                      && argument_array.length >= 1 )
            {
                PrintChangedFiles( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else if ( option == "--print_changes" )
            {
                PrintChanges();
            }
            else if ( option == "--confirm_changes" )
            {
                ConfirmChanges();
            }
            else if ( option == "--apply_changes" )
            {
                ApplyChanges();
            }
            else if ( option == "--exit" )
            {
                Exit();
            }
            else if ( option == "--run"
                      && argument_array.length >= 1 )
            {
                Run( argument_array[ 0 ] );

                argument_array = argument_array[ 1 .. $ ];
            }
            else
            {
                Abort( "Invalid arguments : " ~ argument_array.to!string() );
            }
        }
    }
}

// -- VARIABLES

bool
    CreateOptionIsEnabled,
    VerboseOptionIsEnabled,
    PreviewOptionIsEnabled;

// -- FUNCTIONS


void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    FileException file_exception
    )
{
    PrintError( message );
    PrintError( file_exception.msg );

    exit( -1 );
}

// ~~

bool IsLowerCaseLetter(
    dchar character
    )
{
    return
        ( character >= 'a' && character <= 'z' )
        || character == 'à'
        || character == 'â'
        || character == 'é'
        || character == 'è'
        || character == 'ê'
        || character == 'ë'
        || character == 'î'
        || character == 'ï'
        || character == 'ô'
        || character == 'ö'
        || character == 'û'
        || character == 'ü'
        || character == 'ç'
        || character == 'ñ';
}

// ~~

bool IsUpperCaseLetter(
    dchar character
    )
{
    return
        ( character >= 'A' && character <= 'Z' )
        || character == 'À'
        || character == 'Â'
        || character == 'É'
        || character == 'È'
        || character == 'Ê'
        || character == 'Ë'
        || character == 'Î'
        || character == 'Ï'
        || character == 'Ô'
        || character == 'Ö'
        || character == 'Û'
        || character == 'Ü'
        || character == 'Ñ';
}

// ~~

bool IsLetter(
    dchar character
    )
{
    return
        IsLowerCaseLetter( character )
        || IsUpperCaseLetter( character );
}

// ~~

bool IsDigit(
    dchar character
    )
{
    return character >= '0' && character <= '9';
}

// ~~

dchar GetLowerCaseCharacter(
    dchar character
    )
{
    if ( character >= 'A' && character <= 'Z' )
    {
        return 'a' + ( character - 'A' );
    }
    else
    {
        switch ( character )
        {
            case 'À' : return 'à';
            case 'Â' : return 'â';
            case 'É' : return 'é';
            case 'È' : return 'è';
            case 'Ê' : return 'ê';
            case 'Ë' : return 'ë';
            case 'Î' : return 'î';
            case 'Ï' : return 'ï';
            case 'Ô' : return 'ô';
            case 'Ö' : return 'ö';
            case 'Û' : return 'û';
            case 'Ü' : return 'ü';
            case 'Ñ' : return 'ñ';

            default : return character;
        }
    }
}


// ~~

dchar GetUpperCaseCharacter(
    dchar character
    )
{
    if ( character >= 'a' && character <= 'z' )
    {
        return 'A' + ( character - 'a' );
    }
    else
    {
        switch ( character )
        {
            case 'à' : return 'À';
            case 'â' : return 'Â';
            case 'é' : return 'É';
            case 'è' : return 'È';
            case 'ê' : return 'Ê';
            case 'ë' : return 'Ë';
            case 'î' : return 'Î';
            case 'ï' : return 'Ï';
            case 'ô' : return 'Ô';
            case 'ö' : return 'Ö';
            case 'û' : return 'Û';
            case 'ü' : return 'Ü';
            case 'ç' : return 'C';
            case 'ñ' : return 'Ñ';

            default : return character;
        }
    }
}

// ~~

string GetLowerCaseText(
    string text
    )
{
    string
        lower_case_text;

    foreach ( dchar character; text )
    {
        lower_case_text ~= GetLowerCaseCharacter( character );
    }

    return lower_case_text;
}

// ~~

string GetUpperCaseText(
    string text
    )
{
    string
        upper_case_text;

    foreach ( dchar character; text )
    {
        upper_case_text ~= GetUpperCaseCharacter( character );
    }

    return upper_case_text;
}

// ~~

string GetMinorCaseText(
    string text
    )
{
    if ( text.length >= 2 )
    {
        return text[ 0 .. 1 ].GetLowerCaseText() ~ text[ 1 .. $ ];
    }
    else
    {
        return text.GetLowerCaseText();
    }
}

// ~~

string GetMajorCaseText(
    string text
    )
{
    if ( text.length >= 2 )
    {
        return text[ 0 .. 1 ].GetUpperCaseText() ~ text[ 1 .. $ ];
    }
    else
    {
        return text.GetUpperCaseText();
    }
}

// ~~

string GetCamelCaseText(
    string text
    )
{
    dchar
        prior_character;
    string
        camel_case_text;

    camel_case_text = "";

    prior_character = 0;

    foreach ( dchar character; text )
    {
        if ( character.IsLowerCaseLetter()
             && !prior_character.IsLetter() )
        {
            camel_case_text ~= character.GetUpperCaseCharacter();
        }
        else
        {
            camel_case_text ~= character;
        }

        prior_character = character;
    }

    return camel_case_text;
}

// ~~

string GetSnakeCaseText(
    string text
    )
{
    dchar
        prior_character;
    string
        snake_case_text;

    snake_case_text = "";
    prior_character = 0;

    foreach ( dchar character; text )
    {
        if ( ( prior_character.IsLowerCaseLetter()
               && ( character.IsUpperCaseLetter()
                    || character.IsDigit() ) )
             || ( prior_character.IsDigit()
                  && ( character.IsLowerCaseLetter()
                       || character.IsUpperCaseLetter() ) ) )
        {
            snake_case_text ~= '_';
        }

        snake_case_text ~= character;

        prior_character = character;
    }

    return snake_case_text;
}

// ~~

string ReplacePrefix(
    string text,
    string old_prefix,
    string new_prefix
    )
{
    if ( text.startsWith( old_prefix ) )
    {
        return new_prefix ~ text[ old_prefix.length .. $ ];
    }
    else
    {
        return text;
    }
}

// ~~

string ReplaceSuffix(
    string text,
    string old_suffix,
    string new_suffix
    )
{
    if ( text.endsWith( old_suffix ) )
    {
        return text[ 0 .. text.length.to!long() - old_suffix.length.to!long() ] ~ new_suffix;
    }
    else
    {
        return text;
    }
}

// ~~

string ReplaceCharacters(
    string text,
    string old_characters,
    string new_text
    )
{
    string
        replaced_text;

    foreach ( dchar character; text )
    {
        if ( old_characters.indexOf( character ) >= 0 )
        {
            replaced_text ~= new_text;
        }
        else
        {
            replaced_text ~= character;
        }
    }

    return replaced_text;
}

// ~~

bool MatchesFilter(
    string file_path,
    string file_path_filter
    )
{
    SEGMENTED_FILE_PATH
        segmented_file_path_filter,
        segmented_file_path;

    segmented_file_path.SetFilePath( file_path );
    segmented_file_path_filter.SetFilePath( file_path_filter );

    if ( segmented_file_path_filter.FolderCharacterCount > 0 )
    {
        return
            segmented_file_path.GetFolder().globMatch( segmented_file_path_filter.GetFolderFilter() )
            && segmented_file_path.GetNameExtension().globMatch( segmented_file_path_filter.GetNameExtension() );
    }
    else
    {
        return segmented_file_path.GetNameExtension().globMatch( segmented_file_path_filter.GetNameExtension() );
    }
}

// ~~

bool MatchesExpression(
    string text,
    ref Regex!char expression
    )
{
    return !text.matchFirst( expression ).empty();
}

// ~~

bool AskConfirmation(
    )
{
    writeln( "Do you want to apply these changes ? (y/n)" );

    return readln().toLower().startsWith( "y" );
}

// ~~

void AddFolder(
    string folder_path
    )
{
    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            if ( folder_path != ""
                 && folder_path != "/"
                 && !folder_path.exists() )
            {
                folder_path.mkdirRecurse();
            }
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't add folder : " ~ folder_path, file_exception );
        }
    }
}

// ~~

void RenameFile(
    string old_file_path,
    string new_file_path
    )
{
    SEGMENTED_FILE_PATH
        segmented_file_path;

    if ( !PreviewOptionIsEnabled )
    {
        if ( CreateOptionIsEnabled )
        {
            segmented_file_path.SetFilePath( new_file_path );

            AddFolder( segmented_file_path.GetFolder() );
        }

        try
        {
            old_file_path.rename( new_file_path );
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't move file : " ~ old_file_path ~ " => " ~ new_file_path, file_exception );
        }
    }
}

// ~~

void main(
    string[] argument_array
    )
{
    SCRIPT
        script;

    CreateOptionIsEnabled = false;
    VerboseOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;

    script = new SCRIPT();

    argument_array = argument_array[ 1 .. $ ];

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        script.ParseOption( argument_array );
    }

    if ( argument_array.length > 0 )
    {
        writeln( "Usage :" );
        writeln( "    siren [options]" );
        writeln( "Options :" );
        writeln( "    --create" );
        writeln( "    --verbose" );
        writeln( "    --preview" );
        writeln( "    --include_files file_path_filter" );
        writeln( "    --exclude_files file_path_filter" );
        writeln( "    --select_files file_path_filter" );
        writeln( "    --append_files file_path_filter" );
        writeln( "    --ignore_files file_path_filter" );
        writeln( "    --select_matching_files file_path_expression" );
        writeln( "    --append_matching_files file_path_expression" );
        writeln( "    --ignore_matching_files file_path_expression" );
        writeln( "    --select_found_files" );
        writeln( "    --ignore_found_files" );
        writeln( "    --edit_range first_position post_position" );
        writeln( "    --edit_folder" );
        writeln( "    --edit_folder_name" );
        writeln( "    --edit_folder_name_extension" );
        writeln( "    --edit_name" );
        writeln( "    --edit_name_extension" );
        writeln( "    --edit_extension" );
        writeln( "    --find_range first_position post_position" );
        writeln( "    --find_text format" );
        writeln( "    --find_last_text format" );
        writeln( "    --find_prefix format" );
        writeln( "    --find_suffix format" );
        writeln( "    --find_expression expression" );
        writeln( "    --replace_text old_text new_format" );
        writeln( "    --replace_prefix old_prefix new_format" );
        writeln( "    --replace_suffix old_suffix new_format" );
        writeln( "    --replace_range first_position post_position new_format" );
        writeln( "    --replace_characters old characters new_format" );
        writeln( "    --replace_expression old expression new_expression" );
        writeln( "    --replace_expression_once old expression new_expression" );
        writeln( "    --set_lower_case" );
        writeln( "    --set_upper_case" );
        writeln( "    --set_minor_case" );
        writeln( "    --set_major_case" );
        writeln( "    --set_camel_case" );
        writeln( "    --set_snake_case" );
        writeln( "    --set_edited_text format" );
        writeln( "    --set_found_text format" );
        writeln( "    --remove" );
        writeln( "    --remove_range first_position post_position" );
        writeln( "    --insert_text format position" );
        writeln( "    --insert_prefix format" );
        writeln( "    --insert_suffix format" );
        writeln( "    --write text" );
        writeln( "    --print format" );
        writeln( "    --print_files" );
        writeln( "    --print_selected_files" );
        writeln( "    --print_changed_selected_files" );
        writeln( "    --print_changed_files" );
        writeln( "    --print_changes" );
        writeln( "    --confirm_changes" );
        writeln( "    --apply_changes" );
        writeln( "    --exit" );
        writeln( "    --run script_file_path" );
        writeln( "Commands :" );
        writeln( "    IncludeFiles file_path_filter" );
        writeln( "    ExcludeFiles file_path_filter" );
        writeln( "    SelectFiles file_path_filter" );
        writeln( "    AppendFiles file_path_filter" );
        writeln( "    IgnoreFiles file_path_filter" );
        writeln( "    SelectMatchingFiles file_path_expression" );
        writeln( "    AppendMatchingFiles file_path_expression" );
        writeln( "    IgnoreMatchingFiles file_path_expression" );
        writeln( "    SelectFoundFiles" );
        writeln( "    IgnoreFoundFiles" );
        writeln( "    EditRange first_position post_position" );
        writeln( "    EditFolder" );
        writeln( "    EditFolderName" );
        writeln( "    EditFolderNameExtension" );
        writeln( "    EditName" );
        writeln( "    EditNameExtension" );
        writeln( "    EditExtension" );
        writeln( "    FindRange first_position post_position" );
        writeln( "    FindText format" );
        writeln( "    FindLastText format" );
        writeln( "    FindPrefix format" );
        writeln( "    FindSuffix format" );
        writeln( "    FindExpression expression" );
        writeln( "    ReplaceText old_text new_format" );
        writeln( "    ReplacePrefix old_prefix new_format" );
        writeln( "    ReplaceSuffix old_suffix new_format" );
        writeln( "    ReplaceRange first_position post_position new_format" );
        writeln( "    ReplaceCharacters old_characters new_format" );
        writeln( "    ReplaceExpression old_expression new_expression" );
        writeln( "    ReplaceExpressionOnce old_expression new_expression" );
        writeln( "    SetLowerCase" );
        writeln( "    SetUpperCase" );
        writeln( "    SetMinorCase" );
        writeln( "    SetMajorCase" );
        writeln( "    SetCamelCase" );
        writeln( "    SetSnakeCase" );
        writeln( "    SetEditedText format" );
        writeln( "    SetFoundText format" );
        writeln( "    Remove" );
        writeln( "    RemoveRange first_position post_position" );
        writeln( "    InsertText format position" );
        writeln( "    InsertPrefix format" );
        writeln( "    InsertSuffix format" );
        writeln( "    Print text" );
        writeln( "    PrintFiles format" );
        writeln( "    PrintSelectedFiles format" );
        writeln( "    PrintChangedSelectedFiles format" );
        writeln( "    PrintChangedFiles format" );
        writeln( "    PrintChanges" );
        writeln( "    ConfirmChanges" );
        writeln( "    ApplyChanges" );
        writeln( "    Exit" );
        writeln( "    Run script_file_path" );
        writeln( "File path filter :" );
        writeln( "    file_name_filter" );
        writeln( "    FOLDER_PATH_FILTER/" );
        writeln( "    FOLDER_PATH_FILTER//" );
        writeln( "    FOLDER_PATH_FILTER/file_name_filter" );
        writeln( "    FOLDER_PATH_FILTER//file_name_filter" );
        writeln( "Position :" );
        writeln( "    0, 1, 2, ... : from the start of the edited text" );
        writeln( "    +0, +1, +2, ... : from the start of the edited text" );
        writeln( "    -2, -1, -0, ... : from the end of the edited text" );
        writeln( "    [-1, [0, [1, ... : from the start of the found text" );
        writeln( "    ]-1, ]0, ]1, ... : from the end of the found text" );
        writeln( "Format :" );
        writeln( "    <edited_text> : edited text" );
        writeln( "    <found_text> : found text" );
        writeln( "    <old_folder> : old folder" );
        writeln( "    <old_name> : old name" );
        writeln( "    <old_extension> : old extension" );
        writeln( "    <folder> : folder" );
        writeln( "    <name> : name" );
        writeln( "    <extension> : extension" );
        writeln( "    <year> : year number" );
        writeln( "    <year:2> : year number in two digits" );
        writeln( "    <month> : month number" );
        writeln( "    <month:2> : month number in two digits" );
        writeln( "    <day> : day number" );
        writeln( "    <day:2> : day number in two digits" );
        writeln( "    <hour> : hour number" );
        writeln( "    <hour:2> : hour number in two digits" );
        writeln( "    <minute> : minute number" );
        writeln( "    <minute:2> : minute number in two digits" );
        writeln( "    <second> : second number" );
        writeln( "    <second:2> : second number in two digits" );
        writeln( "    <current_year> : current year number" );
        writeln( "    <current_year:2> : current year number in two digits" );
        writeln( "    <current_month> : current month number" );
        writeln( "    <current_month:2> : current month number in two digits" );
        writeln( "    <current_day> : current day number" );
        writeln( "    <current_day:2> : current day number in two digits" );
        writeln( "    <current_hour> : current hour number" );
        writeln( "    <current_hour:2> : current hour number in two digits" );
        writeln( "    <current_minute> : current minute number" );
        writeln( "    <current_minute:2> : current minute number in two digits" );
        writeln( "    <current_second> : current second number" );
        writeln( "    <current_second:2> : current second number in two digits" );
        writeln( "    \\ : escape next character" );
        writeln( "Examples :" );
        writeln( "    siren --preview --run script_file.siren" );
        writeln( "    siren --create --run script_file.siren" );
        writeln( "    siren --include_files \"*.txt\" --edit_name --set_snake_case --set_lower_case --apply_changes" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
