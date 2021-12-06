#!/usr/bin/env bash

SOUNDS_DIR="$(dirname $0)/sounds"
CACHE_FILE="$(dirname $0)/cache"

cache() {
	echo "Caching useful shit..."
	for filename in "$SOUNDS_DIR"/*
	do
		TITLE_CACHE=$(ffprobe "$filename" 2>&1 | awk '{$1=$1};1' | grep 'title' | cut -d ':' -f 2-)
		ARTIST_CACHE=$(ffprobe "$filename" 2>&1 | awk '{$1=$1};1' | grep 'artist' | cut -d ':' -f 2-)
		echo "$filename;$ARTIST_CACHE;$TITLE_CACHE" >> $CACHE_FILE
	done
}

check_cache_integrity() {
	for filename in "$SOUNDS_DIR"/*
	do
		case `grep -q $filename $CACHE_FILE; echo $?` in
			0)
				;;
			*)
				rm -rf $CACHE_FILE
				cache
				break
				;;
		esac
	done
}

retrieve_titles() {
	grep -i $1 "$CACHE_FILE" | awk -F ";" '{print $2 " : " $3}'
}

retrieve_all_titles() {
	cat "$CACHE_FILE" | awk -F ";" '{print $2 " : " $3}'
}

play_sound() {
	SONG=$(grep $1 "$CACHE_FILE" | cut -d ';' -f 1)
	ffplay -nodisp -autoexit $SONG >/dev/null 2>&1
}

welcome() {
	echo "  
		**********************************************
		*** Welcome to the ultimate AWB soundboard ***
		**********************************************
	"
}

help_text() {
	while IFS= read line; do
		printf "%s\n" "$line"
	done <<-EOF
	USAGE: ./soundboard.sh
	 -h help
	 -a author like ben or naroditsky
	EOF
}

show_board() {
while [ $? -ne 1 ]; do

	if [ -z "$1" ]; then
		CHOICE=$(retrieve_all_titles | sort | dmenu-mac | cut -d ':' -f 2)
	else
		CHOICE=$(retrieve_titles "$1" | sort | dmenu-mac | cut -d ':' -f 2)
	fi
	[[ ! -z $CHOICE ]] && play_sound $CHOICE
done
}

clear


######
#MAIN#
######

welcome

if [ ! -f "$CACHE_FILE" ]; then
	cache
else
	check_cache_integrity
fi

while getopts ':a:h' OPT; do 
	case $OPT in
		a)
			ARTIST="$OPTARG"
			show_board $ARTIST
			;;
		h)
			help_text
			exit 0
			;;
	esac
done
#shift $((OPTIND-1))


while [[ $WHATDO != 'exit' ]]; do
	WHATDO=$(printf "new_sound\nshow_board\nexit" | dmenu-mac)
	case $WHATDO in
		new_sound)
				read -p "Select sound with path -> " sound_upload
				echo "Adding new sound to board -> $sound_upload"
				;;
		show_board)
				show_board
				;;
	esac
done

