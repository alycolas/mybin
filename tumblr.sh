#!/bin/sh

export http_proxy="127.0.0.1:8087"

trap "exit 1" HUP INT PIPE QUIT TERM
trap "rm /tmp/tmp$$" EXIT

creatlist () {
	seq $2 $3 |
	sed -e "s/^.*$/[<a href=$1$2-$3_&.html>&<\/a>]/"
	return
}

for i in `seq $2 $3`
#for i in {$2..$3} 
do
	echo $i
	wget --user-agent=Opera/9.80\ \(X11\;\ Linux\ i686\)\ Presto/2.12.388\ Version/12.15 "http://$1.tumblr.com/page/$i" -O - |
	sed -n -E "s|.*(http://$1.tumblr.com/post/[[:digit:]]{11}).*|\1|p" | uniq |
	while read k
	do
		echo $k
		wget -T3 --user-agent=Opera/9.80\ \(X11\;\ Linux\ i686\)\ Presto/2.12.388\ Version/12.15 "$k" -O /tmp/tmp$$

		if ! grep og:image /tmp/tmp$$
		#if ! grep -E '^\s*<img src=' /tmp/tmp$$ 
		then
			if ! grep twitter:image /tmp/tmp$$ 
			then
				echo $k >&2
			else
				((++j))
			fi
		else
			((++j))
		fi | 
		sed -n -E 's!^.*content="(http://...media.tumblr.com/.*tumblr.*\..*)".*$!\1!p' |
		# cut -d \" -f32 |  不精确
		sed -e "s/^.*$/<img src=\"&\" style=\"margin:2\"\/>/" >> $1$2-$3_$i.html

		rm /tmp/tmp$$

	done 2>/dev/null

	# echo "$(creatlist $1 $2 $3)<p><a href=$1$2-$3_$((i+1)).html>Next</a></p>" >> $1$2-$3_$i.html

	cat >> $1$2-$3_$i.html <<- EOF
	<p>Page $i</p>
	<p>$(creatlist $1 $2 $3)</p>
	<p>[<a href=$1$2-$3_$((i-1)).html>Prev</a>] [<a href=$1$2-$3_$((i+1)).html>Next</a>]</p>
	EOF

done

	# opera list_`date|sed s/\ /_/g`.html
