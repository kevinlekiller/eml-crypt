#!/bin/bash
<<LICENSE
    Copyright (C) 2021  kevinlekiller
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
    https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
LICENSE

<<DESCRIPTION
    Bash script to re-encrypt or decrypt .eml files using gpg and your PGP key.
    Requires grep, perl, gpg.
    Tested with mailbox.org encrypted emails and Thunderbird.
    This script does not parse eml files in subfolders, only the specified folder.
    Examples:
        # Decrypts eml files from from /tmp/Inbox to /tmp/Inbox_D
        INPATH=/tmp/Inbox OUTPATH=/tmp/Inbox_D OUTCHECK=1 ECMODE=decrypt LOGFILE=/tmp/eml-crypt.log ./eml-crypt.sh
        # Re-encrypts eml files from /tmp/Inbox to /tmp/Inbox_R using PGP key E214509407F4175A0674C769C82AD7ACC44AC3DC
        INPATH=/tmp/Inbox OUTPATH=/tmp/Inbox_R OUTCHECK=1 ECMODE=recrypt LOGFILE=/tmp/eml-crypt.log PGPKEYID=E214509407F4175A0674C769C82AD7ACC44AC3DC ./eml-crypt.sh
DESCRIPTION

# Input directory with eml files.
INPATH=${INPATH:-}
# Outpud directory.
OUTPATH=${OUTPATH:-}
# Checks if OUTPATH folder exists. Supress by setting to 0
OUTCHECK=${OUTCHECK:-1}
# To decrypt or recrypt emails.
ECMODE=${ECMODE:-"decrypt"}
# PGP key to use for encryption. Find with pgp --list-keys
PGPKEYID=${PGPKEYID:-}
# Log email conversions success/failure to a file.
LOGFILE=${LOGFILE:-}

if ! [[ -d $INPATH ]]; then
    echo "Must supply directory with .eml files as INPATH variable."
    exit 1
fi

if [[ -z $OUTPATH ]]; then
    echo "Must supply output directory for decrypted .eml files as OUTPATH variable."
    exit 1
fi

if [[ $OUTCHECK == 1 ]] && [[ -d $OUTPATH ]]; then
    echo "Warning: Output directory exists. To supress this warning, set the OUTCHECK variable to 0"
    exit 1
fi

if [[ $INPATH == $OUTPATH ]]; then
    echo "Input and Output directories must be different."
    exit 1
fi

if ! [[ $ECMODE =~ ^[dr]ecrypt$ ]]; then
    echo "ECMODE variable must be one of the following: decrypt | recrypt"
    exit 1
fi

if [[ $ECMODE == "recrypt" ]] && [[ -z $PGPKEYID ]]; then
    echo "You must set the PGP key id to encrypt the emails to the PGPKEYID variable."
    exit 1
fi

if [[ $ECMODE == "recrypt" ]] && [[ $(gpg --list-keys | grep $PGPKEYID) == "" ]]; then
    echo "PGP key not found. Make sure the key is listed in gpg --list-keys"
    exit 1
fi

cd "$INPATH"
OUTPATH="$(echo "$OUTPATH" | sed 's#/*$##')"
mkdir -p "$OUTPATH"

for eml_file in *.eml; do
    if  [[ $(grep -oi "Content-Type: multipart/encrypted" "$eml_file") != "" ]]; then
        perl -0777 -pe 's#Content-Type: multipart/encrypted(.|\r|\n)*$##i' "$eml_file" > "$OUTPATH/$eml_file"
        if [[ $ECMODE == "decrypt" ]]; then
            MESSAGE="Decrypting: $eml_file"
            gpg --decrypt 2> /dev/null <<< $(grep -Pzoi '\-+BEGIN PGP MESSAGE\-+(\r|\n|.)+\-+END PGP MESSAGE\-+.+[\r\n]' "$eml_file") >> "$OUTPATH/$eml_file"
        else
            MESSAGE="Recrypting: $eml_file"
            boundary1=$RANDOM
            boundary2=$RANDOM
            boundary3=$RANDOM
            echo "Content-Type: multipart/encrypted;
        protocol=\"application/pgp-encrypted\";
        boundary=\"$boundary1/$boundary2/$boundary3/eml-crypt.sh\"

This is a MIME-encapsulated message.

--$boundary1/$boundary2/$boundary3/eml-crypt.sh
Content-Type: application/pgp-encrypted
Content-Disposition: attachment

Version: 1

--$boundary1/$boundary2/$boundary3/eml-crypt.sh
Content-Type: application/octet-stream
Content-Disposition: inline; filename=\"msg.asc\"
" >> "$OUTPATH/$eml_file"
            gpg --decrypt 2> /dev/null <<< $(grep -Pzoi '\-+BEGIN PGP MESSAGE\-+(\r|\n|.)+\-+END PGP MESSAGE\-+.+[\r\n]' "$eml_file") | gpg --encrypt --recipient $PGPKEYID --armor 2> /dev/null >> "$OUTPATH/$eml_file"
            echo "
--$boundary1/$boundary2/$boundary3/eml-crypt.sh

" >> "$OUTPATH/$eml_file"
        fi
        if [[ $LOGFILE ]]; then
            echo "$MESSAGE" >> "$LOGFILE"
        fi
        echo "$MESSAGE"
    else
        MESSAGE="NOTICE: Copying email as is; Not encrypted? \"$(realpath "$eml_file")\""
        if [[ $LOGFILE ]]; then
            echo "$MESSAGE" >> "$LOGFILE"
        fi
        echo "$MESSAGE"
        cp "$eml_file" "$OUTPATH/$eml_file"
    fi
done
