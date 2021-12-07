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
			CHOICE=$(retrieve_all_titles | sort | dmenu -l 10 -i | cut -d ':' -f 2)
		else
			CHOICE=$(retrieve_titles "$1" | sort | dmenu -l 10 -i | cut -d ':' -f 2)
		fi
		[[ ! -z $CHOICE ]] && play_sound $CHOICE
	done
}

show_board() {
	while [ $? -ne 1 ]; do
	
		if [ -z "$1" ]; then
			CHOICE=$(retrieve_all_titles | sort | dmenu -l 10 -i | cut -d ':' -f 2)
		else
			CHOICE=$(retrieve_titles "$1" | sort | dmenu -l 10 -i | cut -d ':' -f 2)
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

}

clean_dir() {
	[[ -f "ranges_values.txt" ]] && rm -rf ranges_values.txt
	[[ -f "temp_file_to_slice.mp3" ]] && rm -rf temp_file_to_slice.mp3
}

create_sounds_from_file() {

	clean_dir

	[[ -f "ranges_values.txt" ]] && rm -rf ranges_values.txt
        
	read -p "Enter filename with path: " file_to_slice
	    
	polished_range_in="default"
	        
	while  [ "$polished_range_in" != "exit" ]; do
		read -p "Enter slicing info [starting(seconds),timetoadd(seconds),author,title] es: 30,70,fabi,siamai. Enter to finish: " range_in
		polished_range_in=${range_in:-"exit"}
		[[ $polished_range_in != "exit" ]] && echo "$polished_range_in" >> ranges_values.txt
	done

	check_file=$(basename "$file_to_slice" | rev | cut -f 1 -d '.' | rev)

	[[ ! "$check_file" =~ ^(mp3|wav)$ ]] && echo "Converting to mp3..." && ffmpeg -i "$file_to_slice" temp_file_to_slice.mp3 >/dev/null 2>&1 && file_to_slice="temp_file_to_slice.mp3"

	exec 3<ranges_values.txt
	while IFS= read -u 3 line; do
		echo "Reading file $line"
		starting=$(echo "$line" | cut -d ',' -f 1)
		time_add=$(echo "$line" | cut -d ',' -f 2)
		artist_slice=$(echo "$line" | cut -d ',' -f 3)
		title_slice=$(echo "$line" | cut -d ',' -f 4)
		ffmpeg -ss "$starting" -t "$time_add" -i "$file_to_slice" -metadata artist="${artist_slice:-"Unknown"}" -metadata title="$title_slice" -acodec copy $SOUNDS_DIR/$(($(ls $SOUNDS_DIR | wc -l) + 1)).mp3 >/dev/null 2>&1
		echo "Sound created for -> $artist_slice: $title_slice"
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
	WHATDO=$(printf "new_sound\nplay_from_board\nsend_telegram\ncreate_from_file\nexit" | dmenu -i)
	case $WHATDO in
		new_sound)
				new_sound && check_cache_integrity
				;;
		play_from_board)
				play_from_board
				;;
		send_telegram)	
				show_board
				;;
		create_from_file)
				create_sounds_from_file && check_cache_integrity
				;;
	esac
done

clean_dir

#sudo telegram-send --file sudo telegram-send "message"
