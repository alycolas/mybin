cat >index.html << EOF 
<!doctype html>
<html>
<head>
<title>This is the title of the webpage!</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/dplayer@1.25.0/dist/DPlayer.min.css">
<script src="https://cdn.jsdelivr.net/npm/flv.js@1.5.0/dist/flv.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/hls.js@0.13.1/dist/hls.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/dplayer@1.25.0/dist/DPlayer.min.js"></script>
</head>
<body>
<div id="dplayer"></div>
<script>
const dp = new DPlayer({
container: document.getElementById('dplayer'),
video: {
quality: [
EOF

ls *mkv | sed -e 's/.*/{ name: "\0", url: "\0", type: "auto", },/' >> index.html
# ls *mp4 *mkv | sed -e 's/.*/{ name: "\0", url: "\0", type: "auto", },/' >> index.html


cat >>index.html << EOF 
],
defaultQuality: 0,
pic: 'fanart.jpg',
// thumbnails: 'poster.jpg',
},
});
</script>
</body>
</html>
EOF
