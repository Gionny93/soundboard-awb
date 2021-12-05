#!/usr/bin/env bash

SOUNDS_DIR="$(dirname $0)/sounds"
CACHE_DIR="$(dirname $0)/cache"

cache() {
	echo "Caching useful shit..."
	for filename in "$SOUNDS_DIR"/*
	do
		TITLE=$(ffprobe "$filename" 2>&1 | awk '{$1=$1};1' | grep 'title' | cut -d ':' -f 2-)
		ARTIST=$(ffprobe "$filename" 2>&1 | awk '{$1=$1};1' | grep 'artist' | cut -d ':' -f 2-)
		echo "$filename;$ARTIST;$TITLE" >> $CACHE_DIR
	done
}

check_cache_integrity() {
	for filename in "$SOUNDS_DIR"/*
	do
		case `grep -q $filename $CACHE_DIR; echo $?` in
			0)
				;;
			*)
				rm -rf $CACHE_DIR
				cache
				break
				;;
		esac
	done
}

retrieve_titles() {
	grep -i $1 "$CACHE_DIR" | cut -d ';' -f 3
}

retrieve_all_titles() {
	cat "$CACHE_DIR" | cut -d ';' -f 3
}

play_sound() {
	SONG=$(grep $1 "$CACHE_DIR" | cut -d ';' -f 1)
	ffplay -nodisp -autoexit $SONG >/dev/null 2>&1
}

welcome() {
	echo "  
		**********************************************
		*** Welcome to the ultimate AWB soundboard ***
		**********************************************
	"
}

clear

if [ ! -f "$CACHE_DIR" ]; then
	cache
else
	check_cache_integrity
fi
welcome

if [ $# -eq 0 ]; then
	CHOICE=$(retrieve_all_titles | dmenu -i)
#	play_sound $CHOICE
fi

while getopts ':a:t:' OPT; do 
	case $OPT in
		a)
			ARTIST="$OPTARG"
			CHOICE=$(retrieve_titles "$ARTIST" | dmenu -i)
			;;
	esac
done
shift $((OPTIND-1))

while :; do
	play_sound $CHOICE
	if [ -z $ARTIST ]; then
		CHOICE=$(retrieve_all_titles | dmenu -i)
	else
		CHOICE=$(retrieve_titles "$ARTIST" | dmenu -i)
	fi
done
