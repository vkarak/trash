#!/bin/sh
#
# trash -- a utility for moving files to and manipulating the trash.
#
# Copyright (C) 2006-2007    V. K. Karakasis
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Major Revisions
# ---------------
#
# 25/12/2006: (V. K. Karakasis)	(trash-1.2.4)
# 	- A problem at constructing the absolute file paths in `.trashinfo' info
# 	  files (see Bug #001 and Bug #003) is fixed.
# 	- Greek filenames are now treated correctly (see Bug #004). `getopt -u'
# 	  is used instead of `getopt', in order to return the arguments unquoted.
# 	- `remove_file' does not print a newline after the prompt for deleting.
#
# 05/10/2006: (V. K. Karakasis)	(trash-1.2.3)
#   - `empty_trash' does not print a newline after the prompt for emptying.
#   - `-v' option added to print version number.
#   - Problem when restoring directories is fixed.
#   - While restoring, remove `.trashinfo' only if restoration succeeds.
#
# 05/10/2006: (V. K. Karakasis)  (trash-1.2.2)
#   - Moving the same file into trash several times, now works correctly.
#   - Moving absolute paths to trash works now correctly.
#   - `--help' prints a "real" help message. :)
#   - Program name is now obtained from the `PNAME' variable and instead of the
#     `$0' argument, for maximum portability.
#   - Basename of files is now obtained from the `basename' command.
#   - `--usage' does not print the trash file paths.
#
# 21/08/2006: (V. K. Karakasis)  (trash-1.1.3)
#   - A new option (`-d') was added in order to permanently remove files from
#     trash.
#   - Slight modifications to `-r' option processing were made, too.
#
# 20/08/2006: Revision 1.1 (V. K. Karakasis)  (trash-1.1.1)
#   - First working version
# 

E_PARAM=64
E_EXIST=65
E_ARG=66

PNAME="trash"
PNAME_SC="Trash"
AUTHOR="V. K. Karakasis"
VERSION="1.2.4"

short_opt="d:ehlr:uv"
long_opt="delete:,empty,help,list,restore:,usage,version"
exit_status=0

infosuffix="trashinfo"

# Trash directories
echo ${TRASH=~/.local/share/Trash} > /dev/null
echo ${TRASH_FILES=$TRASH/files} > /dev/null
echo ${TRASH_INFO=$TRASH/info} > /dev/null

# Prints a short help message
function print_help()
{
	echo -e "Usage: $PNAME [OPTION]... FILE..."
	echo -e "Move FILE(s) to trash."
	echo -e "-d [delete-list], --delete=delete-list  permanently remove files"
	echo -e "                                        from trash."
	echo -e "-e, --empty                             empty the trash."
	echo -e "-h, --help                              display this help"\
		"message."
	echo -e "-l, --list                              display a listing of" \
		"the contents of"
	echo -e "                                        the trash."
	echo -e "-r [restore-list], --restore=restore-list restore files"\
		"from trash."
	echo -e "-u, --usage                             display trash usage."
	echo -e "-v, --version                           print version number."
}


function print_version()
{
	echo -e "$PNAME_SC $VERSION"
	echo -e "Copyright (C) 2006-2007\tV. K. Karakasis"
	echo -e ""
	echo -e "This program is free software; you can redistribute it and/or"
	echo -e "modify it under the terms of the GNU General Public License"
	echo -e "as published by the Free Software Foundation; either version 2"
	echo -e "of the License, or (at your option) any later version."
	echo ""
	echo -e "This program is distributed in the hope that it will be useful,"
	echo -e "but WITHOUT ANY WARRANTY; without even the implied warranty of"
	echo -e "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
	echo -e "GNU General Public License for more details."
	echo ""
	echo -e "You should have received a copy of the GNU General Public License"
	echo -e "along with this program; if not, write to the Free Software"
	echo -e "Foundation, Inc., \
51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA."
}


# Move its argument to trash
function move_to_trash()
{
	if [ ! -e $1 ]; then
		echo "$PNAME: \`$1' does not exist" >&2
		return $E_EXIST
	fi

	if [ ! -f $1 ] && [ ! -d $1 ]; then
		echo "$PNAME: \`$1' not a regular file or directory" >&2
		return $E_ARG
	fi

	# obtain the basename
	basename=`basename $1`

	# obtain the full path
	if [ `expr index $1 /` -eq 1 ]; then
		full_path=$1
	else
		# relative path; make it absolute
		full_path=$PWD/$1
	fi

	# check if `basename' exists in trash
	if [ -e $TRASH_FILES/$basename ]; then
		basename=`mktemp -u ${basename}_XXXXXX`
	fi

	infofile=$TRASH_INFO/${basename}.${infosuffix}

	# fill the trash info file
	echo "[Trash Info]" > $infofile
	echo "Path=$full_path" >> $infofile
	echo "DeletionDate=`date +%FT%T`" >> $infofile

	# move to trash
	mv -T $full_path $TRASH_FILES/$basename
}

# Restore files from trash to their original position. The input files
# should be provided as a comma-separated list. No spaces are allowed.
# If any file in the input list does not exist in trash, a warning message
# will be printed and the restoration will proceed to the subsequent files in
# the list.
function restore_file()
{
	# convert the comma separated list to an argument list
	arglist=${1//","/" "}

	for arg in ${arglist}; do

		# expand wildcards in $arg; while substituting the variable, the
		# shell will try to expand any wildcard in $arg. $files contain
		# the absolute path to the requested files, as these are expanded
		# by the shell.
		files=$TRASH_FILES/$arg

		for f in $files; do

			if [ ! -e $f ]; then
				echo "$PNAME: $(basename $f): not found in trash"
				continue
			fi

			infobase=$(basename $f)
			infofile=$TRASH_INFO/${infobase}.${infosuffix}
			
            # get the `Path' record
			if [ -e /usr/bin/fgrep ]; then
				dst=`/usr/bin/fgrep "Path" $infofile`
			else
				dst=`cat $infofile | grep "Path"`
			fi
			
            # get the actual restoration path
			dst=${dst#*=}

            # restore the file
			if mv -iT $f $dst; then
				/bin/rm $infofile
			fi
		done
	done
}

# Completely removes a sequence of files in trash. The input files should be
# provided as a comma-separated list. No spaces are allowed.
function remove_file()
{
	# convert the comma separated list to an argument list
	arglist=${1//","/" "}

	echo -n \
		"Do you really want to permanently delete the selected files? (y/n) "
	read ans
	case $ans in
		"y" | "Y")
			for arg in $arglist; do
				/bin/rm -rf $TRASH_FILES/$arg
				/bin/rm -rf $TRASH_INFO/${arg}.trashinfo
			                          # TRASH_INFO is not supposed to have any
			                          # directory. This is a defensive measure.
			done
			return ;;
		"n" | "N")
			return ;;
		*) echo "Operation aborted: Unrecognized option" ;;
	esac
}

# Lists the trash contents.
function list_trash()
{
	/bin/ls -lh $TRASH_FILES
}

# Empties the trash. Because this is a permanent operation, the user is
# prompted for validation.
function empty_trash()
{
	echo -n "Do you really want to empty the trash? (y/n) "
	read ans
	case $ans in
		"y" | "Y")
			/bin/rm -rf $TRASH_FILES/*
			/bin/rm -rf $TRASH_INFO/* 
                                      # the `-r' is not necessary here.
			                          # TRASH_INFO is not supposed to have any
			                          # directory. This is a defensive measure.
			return ;;
		"n" | "N")
			return ;;
		*) echo "Operation aborted: Unrecognized option" ;;
	esac
}

# Prints trash usage information.
function trash_usage()
{
	echo "[Trash usage]"
	echo "Files   : " `/usr/bin/du -sh $TRASH_FILES | awk '{ print $1 }'`
	echo "Metadata: " `/usr/bin/du -sh $TRASH_INFO | awk '{ print $1 }'`
	echo "Total   : " `/usr/bin/du -sh $TRASH | awk '{ print $1 }'`
}

if [ $# -eq 0 ]; then
	echo "$PNAME: too few arguments"
	echo "Usage: $PNAME [OPTION]... FILE..."
	echo "Try \`$PNAME --help' for more information"
	exit $E_PARAM
fi

getopt_args=`getopt -n $PNAME -l $long_opt -o $short_opt -u -- $*`

# getopt failed; print a message and exit
if [ ! $? -eq 0 ]; then
	echo "Try \`$PNAME --help' for more information"
	exit $E_ARG
fi

rflag=0;
dflag=0;
for arg in $getopt_args ; do

	case $arg in
		"-d" | "--delete") dflag=1 ;;
		"-e" | "--empty")
			empty_trash
			exit 0 ;;
		"-h" | "--help")
			print_help
			exit 0 ;;
		"-l" | "--list")
			list_trash
			exit 0 ;;
		"-r" | "--restore") rflag=1 ;;
		"-u" | "--usage")
			trash_usage
			exit 0 ;;
		"-v" | "--version")
			print_version
			exit 0 ;;
		"--") ;;            # non-option arugment separator
		*)
		    # strip quotes before processing arguments
			#arg=${arg:1:((`expr length $arg` - 2))}
			if [ $rflag -ne 0 ]; then
				# -r option specified
				restore_file $arg
				rflag=0
			elif [ $dflag -ne 0 ]; then
				# -d option specified
				remove_file $arg
				dflag=0
			else
				move_to_trash $arg
			fi ;;
	esac
done

exit $?
