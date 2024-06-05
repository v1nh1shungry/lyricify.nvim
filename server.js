const http = require("http");

let lyric = null;

const server = http.createServer((req, res) => {
  req.statusCode = 200;
  if (req.method === "GET") {
    res.write(lyric || String.raw`{"error": "没有正在播放的歌曲"}`);
  } else if (req.method === "POST") {
    req.on("data", chunk => { lyric = chunk });
  }
  res.end();
});

server.on("error", (_) => {});

server.listen(12138);
