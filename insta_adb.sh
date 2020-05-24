#!/bin/bash
a_SHELL="adb shell"
a_TAP="adb shell input tap"
a_EVENT="adb shell sendevent /dev/input/event2"
a_SWIPE="adb shell input touchscreen swipe"

btmHOME="1847 535"
btmINSTA="680 670"

PROFILE="968 1710"
TAGS=( # ~55px Y
	"100 838"
	"100 900"
	"100 960"
	"100 1008"
	"100 1062"
	"100 1120"
	"100 1175"
)
HOME="106 1710"

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

go_profile() {
	log "$FUNCNAME"
	go_to $PROFILE
}
kill_instagram() {
	adb shell am force-stop com.instagram.android || log "not running?"
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

go_tags() {
	max_likes=60
	current_likes=0
	tag_no=1
	tag="${TAGS[$(rand 0-7)]}"

	log "TAG: $tag_no ($tag)"
	tag_no=$(($tag_no+1))
	go_profile
	# Press more on tags list
	go_to 522 1010
	slp
	go_to $tag
	slp

	# Need to skip videos
	$a_SWIPE $(rand 700-900) $(rand 1300-1500) $(rand 700-900) $(rand 300-400) $(rand 190-270)
	slp $(rand 3-5)
	
	while [ ${current_likes} -lt ${max_likes} ]; do
		swipe_n_like
		#	      cur_like + like_or_not(1/0)
		current_likes=$(($current_likes+$?))
		log "like: $current_likes - max: $max_likes"
	done

	log "done with TAG: $tag_no ($tag)"
	current_likes=0
	slp
	kill_instagram
	slp $(rand 60-120)
	run_instagram
	slp $(rand 10-15)
}




swipe_n_like() {
	while [ $(rand 1-3) -ne 1 ]; do
		log "swipe..."
		# 		start X		start Y		end X		end Y		swipe time
		$a_SWIPE $(rand 700-900) $(rand 1300-1500) $(rand 700-900) $(rand 300-400) $(rand 190-270)
		slp 0.$(rand "2-9")
	done
	# Doubletap
	if [ $(rand 1-2) -ne 1 ]; then
		$a_SHELL 'cat /sdcard/doubletap_1 > /dev/input/event1 && sleep 0.12 && cat /sdcard/doubletap_1 > /dev/input/event1'
		slp $(rand_dig "10-15" "10-90")
		log "liked!"
		slp $(rand_dig "10-15" "10-90")
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
		log "started in $MODE"
		run_instagram
		slp $(rand 10-15)
		while true; do
			go_tags
		done
		;;
	*)
		log "started in $MODE"
		go_tags
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
