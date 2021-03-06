#!/bin/bash

# exit on any errors
# set -e

a_SHELL="adb shell"
a_TAP="adb shell input tap"
a_EVENT="adb shell sendevent /dev/input/event2"
a_SWIPE="adb shell input touchscreen swipe"

btmHOME="1847 535"
btmINSTA="680 670"
btmBACK="243 1847"

PROFILE="968 1710"

# ~55px Y
TAGS=("" "100 838" "100 900" "100 960" "100 1008" "100 1062" "100 1120" "100 1175")
HOME="106 1710"

MAX_LIKE_PER_TAG=30

randTag_no="2-7"
randSwipe="1-2"
randLike="1-2"
randSleepAfterLike="5-10"
randGoBack="1-50"
randFastScroll="1-3"
randFastScrollTimes="5-10"
randSleepAfterKill="40-60"
randSleepAfterStart="10-15"

source /home/${USER}/ENV/3/bin/activate

# Utils
log() {
	echo "`date '+%Y-%m-%d %H:%M'` -- $1"
}
slp() {
	S=${1:-0.5}
	log "sleep for $S..."
	sleep $S
}
rand() {
	echo $(shuf -n 1 -i $1)
}
rand_dig() {
	DELIM=${3:-"."}
	echo $(shuf -n 1 -i $1)${DELIM}$(shuf -n 1 -i $2)
}

# Go To
go_to() {
	X=$1
	Y=$2
	swX=$(expr $X - 6)
	swY=$(expr $Y - 6)
	HOLD=$(rand 100-200)
	log "$FUNCNAME - $a_SWIPE $X $Y $swX $swY $HOLD"
	$a_SWIPE $X $Y $swX $swY $HOLD
	echo ""
}

go_home() {
	log "$FUNCNAME"
	go_to $HOME
}

go_back() {
	log "$FUNCNAME"
	go_to $btmBACK
}
go_profile() {
	log "$FUNCNAME"
	go_to $PROFILE
}
swipe() {
	log "$FUNCNAME"
	# 		start X		start Y		end X		end Y		swipe time
	$a_SWIPE $(rand 700-900) $(rand 1300-1500) $(rand 700-900) $(rand 300-400) $(rand 190-270)
	slp 0.$(rand "2-9")
}

# Notification
telegram_nofity() {
	telegram-send --config /home/${USER}/.config/telegram-send.conf $1
	
}

# Exec
kill_instagram() {
	adb shell am force-stop com.instagram.android || log "not running?"
	log "$FUNCNAME - killed"
}
run_instagram() {
	log "$FUNCNAME"
	# Set lowest brightness
	adb shell settings put system screen_brightness_mode 0
	adb shell settings put system screen_brightness 0

	log "killing running instagram"
	kill_instagram
	go_to $btmHOME
	slp 1
	go_to $btmHOME
	go_to $btmINSTA
}

run_main() {
	# vars
	max_likes=$( rand ${MAX_LIKE_PER_TAG}-$(($MAX_LIKE_PER_TAG+10)) )
	half_likes=$(($max_likes/2))
	current_likes=0
	tag_no=1

	# Take a random tag from profile bio
	tag="${TAGS[$(rand $randTag_no)]}"
	log "TAG: $tag_no ($tag)"
	tag_no=$(($tag_no+1))
	go_profile
	slp $(rand 3-5)
	go_to 522 1010  # Press more on tags list (need to kill insta every time)
	slp $(rand 1-2)
	go_to $tag
	slp $(rand 3-4)
	go_to 758 786  # Show Recents
	slp $(rand 4-5)

	# Need to skip videos at the beggining
	$a_SWIPE $(rand 700-900) $(rand 1300-1500) $(rand 700-900) $(rand 300-400) $(rand 190-270)
	slp $(rand 3-5)
	
	while [ ${current_likes} -lt ${max_likes} ]; do
		swipe_n_like

		#	      cur_like + like_or_not(1/0)
		current_likes=$(($current_likes+$?))
		log "like: $current_likes - max: $max_likes"
		

		# sometimes go back 
		if [ ${current_likes} -gt ${half_likes} ]; then
			log "${current_likes} is bigger than half: ${half_likes}"
			if [ $(rand $randGoBack) -eq 1 ]; then
				go_back
			fi

		# fast scroll
		elif [ ${current_likes} -lt 2 ]; then
			if [ $(rand $randFastScroll) -eq 1 ]; then
				scroll=0
				scroll_times=$(rand $randFastScrollTimes)
				while [ ${scroll} -lt ${scroll_times} ]; do
					log "fast scroll: $scroll of $scroll_times"
					swipe
					scroll=$(($scroll+1))
				done
			fi
		fi
	done

	# afterparty
	log "done with TAG: $tag_no ($tag)"
	current_likes=0
	slp
	kill_instagram
	slp $(rand $randSleepAfterKill)
	run_instagram
	slp $(rand $randSleepAfterStart)
}




swipe_n_like() {
	# Swiping
	while [ $(rand $randSwipe) -ne 1 ]; do
		swipe
	done

	# Doubletap
	if [ $(rand $randLike) -ne 1 ]; then
		$a_SHELL 'cat /sdcard/doubletap_1 > /dev/input/event1 && sleep 0.12 && cat /sdcard/doubletap_1 > /dev/input/event1'
		slp $(rand_dig $randSleepAfterLike "10-90")
		log "liked!"
		slp $(rand_dig $randSleepAfterLike "10-90")
		swipe
		return 1
	else
		log "not liked"
		return 0
	fi
}

log "Instagram ADB auto-liker by shellshock"
MODE=${1:-prod}
case $MODE in 
	prod)
		#telegram_nofity "[ok]InstaADB_started"
		log "started in $MODE"
		adb devices
		run_instagram
		slp $(rand 10-15)
		while true; do
			run_main
		done
		;;
	exit)
		#telegram_nofity "[!_]InstaADB_stopted"
		kill_instagram
		;;
	fail)
		telegram_nofity "[!!]InstaADB_FAILS"
		;;
	*)
		log "started in $MODE"
		run_main
esac



# TIPS
# https://superuser.com/questions/1173378/using-adb-to-sendevent-touches-to-the-phone-but-cant-release
# adb shell getevent | grep --line-buffered ^/ | tee /tmp/android-touch-events.log
# awk '{printf "%s %d %d %d\n", substr($1, 1, length($1) -1), strtonum("0x"$2), strtonum("0x"$3), strtonum("0x"$4)}' /tmp/android-touch-events.log | xargs -l adb shell sendevent

# some noname site
# adb shell
# cd /sdcard/
# cat /dev/input/event1 > doubletap
# cat doubletap > /dev/input/event1 && sleep 0.1 && cat doubletap > /dev/input/event1
