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

clear_cache() {
	rm -rf $CACHE_FILE
}

check_cache_integrity() {
	for filename in "$SOUNDS_DIR"/*
	do
		case `grep -q $filename $CACHE_FILE; echo $?` in
			0)
				;;
			*)
				clear_cache
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

send_telegram() {
	SONG=$(grep $1 "$CACHE_FILE" | cut -d ';' -f 1)
	sudo telegram-send --file $SONG
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

play_from_board() {
	while [ $? -ne 1 ]; do
	
		if [ -z "$1" ]; then
			CHOICE=$(retrieve_all_titles | sort | dmenu -l 5 -i | cut -d ':' -f 2)
		else
			CHOICE=$(retrieve_titles "$1" | sort | dmenu -l 5 -i | cut -d ':' -f 2)
		fi
		[[ ! -z $CHOICE ]] && play_sound $CHOICE
	done
}

show_board() {
	while [ $? -ne 1 ]; do
	
		if [ -z "$1" ]; then
			CHOICE=$(retrieve_all_titles | sort | dmenu -l 5 -i | cut -d ':' -f 2)
		else
			CHOICE=$(retrieve_titles "$1" | sort | dmenu -l 5 -i | cut -d ':' -f 2)
		fi
		[[ ! -z $CHOICE ]] && send_telegram $CHOICE
	done
}

new_sound() {
	read -p "Select sound with path -> " sound_upload

	read -p "Choose an Artist for the new sound -> " new_artist_in

	default_artist="Unknown"
	new_artist="${new_artist_in:-$default_artist}"

	read -p "Choose a title for the new sound -> " new_sound_name_in

	default_sound_name=$(basename "$sound_upload" | rev | cut -f 2- -d '.' | rev)
	new_sound_name="${new_sound_name_in:-$default_sound_name}"

	echo "Adding new sound to board -> $new_artist: $new_sound_name"

	ffmpeg -i "$sound_upload" -metadata artist="$new_artist" -metadata title="$new_sound_name" -c:a copy $SOUNDS_DIR/$(($(ls $SOUNDS_DIR | wc -l) + 1)).mp3 >/dev/null 2>&1

	echo "Successfully added :)"

#	clear_cache && cache
	check_cache_integrity
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
			play_from_board $ARTIST
			;;
		h)
			help_text
			exit 0
			;;
	esac
done
#shift $((OPTIND-1))


while [[ $WHATDO != 'exit' ]]; do
	WHATDO=$(printf "new_sound\nplay_from_board\nsend_telegram\nexit" | dmenu -i)
	case $WHATDO in
		new_sound)
				new_sound
				;;
		play_from_board)
				play_from_board
				;;
		send_telegram)	show_board
				;;
	esac
done

#sudo telegram-send --file sudo telegram-send "message"
#ffmpeg -ss 30 -t 70 -i inputfile.mp3 -acodec copy outputfile.mp3   starting at 30s add 70seconds 
